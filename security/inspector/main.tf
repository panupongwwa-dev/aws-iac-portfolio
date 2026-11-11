data "aws_caller_identity" "current" {}

# Enable Inspector v2 for specific resource types in this account. AWS
# rejects a single aws_inspector2_enabler whose account_ids mixes the
# admin account with member accounts ("can contain either the
# administrator account or one or more member accounts") — this one is
# always exactly the calling account, whether that's a standalone member
# (a workload account's own use of this module) or the delegated admin itself.
resource "aws_inspector2_enabler" "this" {
  account_ids    = coalescelist(var.account_ids, [data.aws_caller_identity.current.account_id])
  resource_types = var.resource_types

  timeouts {
    create = "15m"
    update = "15m"
    delete = "15m"
  }
}

# Explicitly enable specific MEMBER accounts from the delegated admin —
# the workaround for global-security-baseline's SCP blocking
# aws_inspector2_organization_configuration's auto_enable (see the
# comment on that resource below): inspector2:Enable is a different,
# unblocked action. Only meaningful when is_delegated_admin = true.
resource "aws_inspector2_enabler" "members" {
  count = length(var.member_account_ids) > 0 ? 1 : 0

  account_ids    = var.member_account_ids
  resource_types = var.resource_types

  timeouts {
    create = "15m"
    update = "15m"
    delete = "15m"
  }
}

# Delegate Inspector v2 admin to a member account — run from management account
resource "aws_inspector2_delegated_admin_account" "this" {
  count      = var.delegated_admin_account_id != null ? 1 : 0
  account_id = var.delegated_admin_account_id
}

# Org-wide auto-enable configuration — run from the delegated admin account
resource "aws_inspector2_organization_configuration" "this" {
  count = var.is_delegated_admin ? 1 : 0

  auto_enable {
    ec2         = var.auto_enable.ec2
    ecr         = var.auto_enable.ecr
    lambda      = var.auto_enable.lambda
    lambda_code = var.auto_enable.lambda_code
  }

  depends_on = [aws_inspector2_enabler.this]
}

# Finding suppression filters
resource "aws_inspector2_filter" "this" {
  for_each = var.filters

  name        = each.key
  description = each.value.description
  action      = each.value.action

  filter_criteria {
    dynamic "aws_account_id" {
      for_each = each.value.criteria.aws_account_ids
      content {
        comparison = aws_account_id.value.comparison
        value      = aws_account_id.value.value
      }
    }

    dynamic "severity" {
      for_each = each.value.criteria.severities
      content {
        comparison = severity.value.comparison
        value      = severity.value.value
      }
    }

    dynamic "resource_type" {
      for_each = each.value.criteria.resource_types
      content {
        comparison = resource_type.value.comparison
        value      = resource_type.value.value
      }
    }

    dynamic "finding_status" {
      for_each = each.value.criteria.finding_statuses
      content {
        comparison = finding_status.value.comparison
        value      = finding_status.value.value
      }
    }

    dynamic "ecr_image_tags" {
      for_each = each.value.criteria.ecr_image_tags
      content {
        comparison = ecr_image_tags.value.comparison
        value      = ecr_image_tags.value.value
      }
    }

    dynamic "vulnerability_id" {
      for_each = each.value.criteria.vulnerability_ids
      content {
        comparison = vulnerability_id.value.comparison
        value      = vulnerability_id.value.value
      }
    }
  }

  tags = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)
}
