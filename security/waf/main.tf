data "aws_caller_identity" "current" {}

locals {
  # flatten (acl, resource_arn) pairs for association (REGIONAL only)
  acl_associations = {
    for pair in flatten([
      for acl_key, acl in var.web_acls : [
        for idx, arn in acl.associate_resource_arns : { key = "${acl_key}::${idx}", acl_key = acl_key, arn = arn }
      ]
    ]) : pair.key => pair
  }
}

resource "aws_wafv2_web_acl" "this" {
  for_each = var.web_acls

  name        = each.key
  description = each.value.description != "" ? each.value.description : null
  scope       = each.value.scope

  default_action {
    dynamic "allow" {
      for_each = each.value.default_action == "allow" ? [1] : []
      content {}
    }
    dynamic "block" {
      for_each = each.value.default_action == "block" ? [1] : []
      content {}
    }
  }

  # AWS managed rule groups
  dynamic "rule" {
    for_each = { for r in each.value.managed_rule_groups : r.name => r }
    content {
      name     = rule.value.name
      priority = rule.value.priority

      override_action {
        dynamic "none" {
          for_each = rule.value.override_action == "none" ? [1] : []
          content {}
        }
        dynamic "count" {
          for_each = rule.value.override_action == "count" ? [1] : []
          content {}
        }
      }

      statement {
        managed_rule_group_statement {
          name        = rule.value.name
          vendor_name = rule.value.vendor_name
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = each.value.cloudwatch_metrics_enabled
        metric_name                = rule.value.name
        sampled_requests_enabled   = each.value.sampled_requests_enabled
      }
    }
  }

  # rate-based rules (block when an IP exceeds the limit)
  dynamic "rule" {
    for_each = { for r in each.value.rate_based_rules : r.name => r }
    content {
      name     = rule.value.name
      priority = rule.value.priority

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit              = rule.value.limit
          aggregate_key_type = rule.value.aggregate_key
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = each.value.cloudwatch_metrics_enabled
        metric_name                = rule.value.name
        sampled_requests_enabled   = each.value.sampled_requests_enabled
      }
    }
  }

  # geo allow-list (block anything NOT from the listed countries)
  dynamic "rule" {
    for_each = each.value.geo_allow_rule != null ? [each.value.geo_allow_rule] : []
    content {
      name     = rule.value.name
      priority = rule.value.priority

      action {
        block {}
      }

      statement {
        not_statement {
          statement {
            geo_match_statement {
              country_codes = rule.value.country_codes
            }
          }
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = each.value.cloudwatch_metrics_enabled
        metric_name                = rule.value.name
        sampled_requests_enabled   = each.value.sampled_requests_enabled
      }
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = each.value.cloudwatch_metrics_enabled
    metric_name                = each.key
    sampled_requests_enabled   = each.value.sampled_requests_enabled
  }

  tags = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)
}

resource "aws_wafv2_web_acl_association" "this" {
  for_each = local.acl_associations

  resource_arn = each.value.arn
  web_acl_arn  = aws_wafv2_web_acl.this[each.value.acl_key].arn
}

# ---- WAF Logging → CloudWatch Logs -------------------------------------------
locals {
  acls_with_logging = { for k, v in var.web_acls : k => v if v.log_retention_days != null }
}

resource "aws_cloudwatch_log_group" "waf" {
  for_each = local.acls_with_logging

  # WAF requires log group names to start with "aws-waf-logs-"
  name              = "aws-waf-logs-${each.key}"
  retention_in_days = each.value.log_retention_days
  tags              = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)
}

resource "aws_cloudwatch_log_resource_policy" "waf" {
  count = length(local.acls_with_logging) > 0 ? 1 : 0

  policy_name = "wafv2-logs"
  policy_document = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "delivery.logs.amazonaws.com" }
      Action    = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource  = [for k in keys(local.acls_with_logging) : "${aws_cloudwatch_log_group.waf[k].arn}:*"]
      Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id } }
    }]
  })
}

resource "aws_wafv2_web_acl_logging_configuration" "this" {
  for_each = local.acls_with_logging

  resource_arn            = aws_wafv2_web_acl.this[each.key].arn
  log_destination_configs = [aws_cloudwatch_log_group.waf[each.key].arn]
  depends_on              = [aws_cloudwatch_log_resource_policy.waf]
}
