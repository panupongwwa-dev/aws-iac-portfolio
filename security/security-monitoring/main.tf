data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  # Region-aware default standards. Used when var.securityhub_standards_arns is empty.
  default_standards_arns = {
    aws_foundational_security = "arn:${data.aws_partition.current.partition}:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
    cis_aws_1_4               = "arn:${data.aws_partition.current.partition}:securityhub:${data.aws_region.current.name}::standards/cis-aws-foundations-benchmark/v/1.4.0"
  }
  effective_standards_arns = length(var.securityhub_standards_arns) > 0 ? var.securityhub_standards_arns : local.default_standards_arns
}

resource "aws_guardduty_detector" "this" {
  count  = var.enable_guardduty ? 1 : 0
  enable = true
  tags   = merge({ ManagedBy = "terraform" }, var.tags)
}

resource "aws_guardduty_detector_feature" "s3_logs" {
  count       = var.enable_guardduty ? 1 : 0
  detector_id = aws_guardduty_detector.this[0].id
  name        = "S3_DATA_EVENTS"
  status      = var.guardduty_s3_logs ? "ENABLED" : "DISABLED"
}

resource "aws_guardduty_detector_feature" "eks_audit_logs" {
  count       = var.enable_guardduty ? 1 : 0
  detector_id = aws_guardduty_detector.this[0].id
  name        = "EKS_AUDIT_LOGS"
  status      = var.guardduty_kubernetes_audit_logs ? "ENABLED" : "DISABLED"
}

resource "aws_guardduty_detector_feature" "malware_protection" {
  count       = var.enable_guardduty ? 1 : 0
  detector_id = aws_guardduty_detector.this[0].id
  name        = "EBS_MALWARE_PROTECTION"
  status      = var.guardduty_malware_protection ? "ENABLED" : "DISABLED"
}

resource "aws_guardduty_organization_configuration" "this" {
  count       = var.enable_guardduty && var.is_guardduty_delegated_admin ? 1 : 0
  detector_id = aws_guardduty_detector.this[0].id

  auto_enable_organization_members = var.guardduty_auto_enable_org_members
}

resource "aws_securityhub_account" "this" {
  count = var.enable_security_hub ? 1 : 0

  enable_default_standards = var.securityhub_enable_default_standards
  auto_enable_controls     = var.securityhub_auto_enable_controls
}

resource "aws_securityhub_standards_subscription" "this" {
  for_each = var.enable_security_hub ? local.effective_standards_arns : {}

  standards_arn = each.value
  depends_on    = [aws_securityhub_account.this]
}

resource "aws_securityhub_organization_configuration" "this" {
  count = var.enable_security_hub && var.is_securityhub_delegated_admin ? 1 : 0

  auto_enable           = var.securityhub_auto_enable_org_members
  auto_enable_standards = var.securityhub_auto_enable_org_standards ? "DEFAULT" : "NONE"

  depends_on = [aws_securityhub_account.this]
}
