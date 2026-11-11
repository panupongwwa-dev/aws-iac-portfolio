resource "aws_guardduty_detector" "this" {
  enable                       = var.enable
  finding_publishing_frequency = var.finding_publishing_frequency
  tags                         = merge({ ManagedBy = "terraform" }, var.tags)
}

resource "aws_guardduty_detector_feature" "s3_logs" {
  detector_id = aws_guardduty_detector.this.id
  name        = "S3_DATA_EVENTS"
  status      = var.datasources.s3_logs ? "ENABLED" : "DISABLED"
}

resource "aws_guardduty_detector_feature" "eks_audit_logs" {
  detector_id = aws_guardduty_detector.this.id
  name        = "EKS_AUDIT_LOGS"
  status      = var.datasources.kubernetes_audit_logs ? "ENABLED" : "DISABLED"
}

resource "aws_guardduty_detector_feature" "malware_protection" {
  detector_id = aws_guardduty_detector.this.id
  name        = "EBS_MALWARE_PROTECTION"
  status      = var.datasources.malware_protection ? "ENABLED" : "DISABLED"
}

# Configures org-wide auto-enable — run from the delegated admin account
resource "aws_guardduty_organization_configuration" "this" {
  count       = var.is_delegated_admin ? 1 : 0
  detector_id = aws_guardduty_detector.this.id

  auto_enable_organization_members = var.auto_enable_org_members
}

resource "aws_guardduty_organization_configuration_feature" "s3_logs" {
  count       = var.is_delegated_admin ? 1 : 0
  detector_id = aws_guardduty_detector.this.id
  name        = "S3_DATA_EVENTS"
  auto_enable = var.datasources.s3_logs ? var.auto_enable_org_members : "NONE"
  depends_on  = [aws_guardduty_organization_configuration.this]
}

resource "aws_guardduty_organization_configuration_feature" "eks_audit_logs" {
  count       = var.is_delegated_admin ? 1 : 0
  detector_id = aws_guardduty_detector.this.id
  name        = "EKS_AUDIT_LOGS"
  auto_enable = var.datasources.kubernetes_audit_logs ? var.auto_enable_org_members : "NONE"
  depends_on  = [aws_guardduty_organization_configuration.this]
}

resource "aws_guardduty_organization_configuration_feature" "malware_protection" {
  count       = var.is_delegated_admin ? 1 : 0
  detector_id = aws_guardduty_detector.this.id
  name        = "EBS_MALWARE_PROTECTION"
  auto_enable = var.datasources.malware_protection ? var.auto_enable_org_members : "NONE"
  depends_on  = [aws_guardduty_organization_configuration.this]
}

# Suppression / archive filters
resource "aws_guardduty_filter" "this" {
  for_each = var.filters

  name        = each.key
  action      = each.value.action
  detector_id = aws_guardduty_detector.this.id
  rank        = each.value.rank

  finding_criteria {
    dynamic "criterion" {
      for_each = each.value.criteria
      content {
        field                 = criterion.key
        equals                = criterion.value.equals
        not_equals            = criterion.value.not_equals
        greater_than          = criterion.value.greater_than
        greater_than_or_equal = criterion.value.greater_than_or_equal
        less_than             = criterion.value.less_than
        less_than_or_equal    = criterion.value.less_than_or_equal
      }
    }
  }

  tags = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)
}

# Export findings to S3 or EventBridge
resource "aws_guardduty_publishing_destination" "this" {
  for_each = var.publishing_destinations

  detector_id      = aws_guardduty_detector.this.id
  destination_arn  = each.value.destination_arn
  destination_type = each.value.destination_type
  kms_key_arn      = each.value.kms_key_arn
}
