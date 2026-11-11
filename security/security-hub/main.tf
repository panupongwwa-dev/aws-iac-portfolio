resource "aws_securityhub_account" "this" {
  enable_default_standards  = var.enable_default_standards
  auto_enable_controls      = var.auto_enable_controls
  control_finding_generator = var.control_finding_generator
}

# Subscribe to compliance standards (CIS, FSBP, PCI-DSS, NIST, etc.)
resource "aws_securityhub_standards_subscription" "this" {
  for_each = var.standards_arns

  standards_arn = each.value
  depends_on    = [aws_securityhub_account.this]
}

# Aggregate findings from multiple regions into one home region
resource "aws_securityhub_finding_aggregator" "this" {
  count = var.finding_aggregator != null ? 1 : 0

  linking_mode      = var.finding_aggregator.linking_mode
  specified_regions = length(var.finding_aggregator.specified_regions) > 0 ? var.finding_aggregator.specified_regions : null

  depends_on = [aws_securityhub_account.this]
}

# Org-wide auto-enable — run from the delegated admin account
resource "aws_securityhub_organization_configuration" "this" {
  count = var.is_delegated_admin ? 1 : 0

  auto_enable           = var.auto_enable_org_members
  auto_enable_standards = var.auto_enable_org_standards ? "DEFAULT" : "NONE"

  depends_on = [aws_securityhub_account.this]
}

# Custom insights for saved finding queries
resource "aws_securityhub_insight" "this" {
  for_each = var.insights

  name               = each.key
  group_by_attribute = each.value.group_by_attribute

  filters {
    dynamic "severity_label" {
      for_each = each.value.filters.severity_labels
      content {
        comparison = "EQUALS"
        value      = severity_label.value
      }
    }

    dynamic "workflow_status" {
      for_each = each.value.filters.workflow_statuses
      content {
        comparison = "EQUALS"
        value      = workflow_status.value
      }
    }

    dynamic "record_state" {
      for_each = each.value.filters.record_states
      content {
        comparison = "EQUALS"
        value      = record_state.value
      }
    }

    dynamic "product_name" {
      for_each = each.value.filters.product_names
      content {
        comparison = "EQUALS"
        value      = product_name.value
      }
    }
  }

  depends_on = [aws_securityhub_account.this]
}

# Custom action targets (for integrations like Jira, PagerDuty via EventBridge)
resource "aws_securityhub_action_target" "this" {
  for_each = var.action_targets

  name        = each.key
  identifier  = each.value.identifier
  description = each.value.description

  depends_on = [aws_securityhub_account.this]
}
