data "aws_partition" "current" {}

locals {
  # Merge exclusion condition into each statement when excluded_role_arns is provided
  exclusion = length(var.excluded_role_arns) > 0 ? {
    Condition = {
      StringNotLike = {
        "aws:PrincipalARN" = var.excluded_role_arns
      }
    }
  } : {}
}

resource "aws_organizations_policy" "this" {
  name        = var.name
  description = var.description
  type        = "SERVICE_CONTROL_POLICY"
  tags        = merge({ ManagedBy = "terraform" }, var.tags)

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      merge({
        Sid    = "DenyDisableGuardDuty"
        Effect = "Deny"
        Action = [
          "guardduty:DeleteDetector",
          "guardduty:DisassociateFromAdministratorAccount",
          "guardduty:DisassociateMembers",
          "guardduty:StopMonitoringMembers",
          "guardduty:UpdateDetector",
          "guardduty:DeletePublishingDestination",
          "guardduty:UpdatePublishingDestination"
        ]
        Resource = ["*"]
      }, local.exclusion),

      merge({
        Sid    = "DenyDisableSecurityHub"
        Effect = "Deny"
        Action = [
          "securityhub:DeleteHub",
          "securityhub:DisableSecurityHub",
          "securityhub:BatchDisableStandards",
          "securityhub:UpdateStandardsControl"
        ]
        Resource = ["*"]
      }, local.exclusion),

      merge({
        Sid    = "DenyDisableConfig"
        Effect = "Deny"
        Action = [
          "config:DeleteConfigRule",
          "config:DeleteConfigurationRecorder",
          "config:DeleteDeliveryChannel",
          "config:StopConfigurationRecorder",
          "config:DeleteOrganizationConfigRule",
          "config:DeleteOrganizationConformancePack"
        ]
        Resource = ["*"]
      }, local.exclusion),

      merge({
        Sid    = "DenyDisableInspector"
        Effect = "Deny"
        Action = [
          "inspector2:Disable",
          "inspector2:DisassociateMember",
          "inspector2:UpdateOrganizationConfiguration"
        ]
        Resource = ["*"]
      }, local.exclusion),

      merge({
        Sid    = "DenyDisableAccessAnalyzer"
        Effect = "Deny"
        Action = [
          "access-analyzer:DeleteAnalyzer",
          "access-analyzer:UpdateFindings"
        ]
        Resource = ["*"]
      }, local.exclusion),

      merge({
        Sid    = "DenyDisableIAMAccessAdvisor"
        Effect = "Deny"
        Action = [
          "iam:DeleteServiceLinkedRole"
        ]
        Resource = ["arn:${data.aws_partition.current.partition}:iam::*:role/aws-service-role/access-analyzer.amazonaws.com/*"]
      }, local.exclusion)
    ]
  })
}

resource "aws_organizations_policy_attachment" "this" {
  for_each  = toset(var.target_ids)
  policy_id = aws_organizations_policy.this.id
  target_id = each.value
}
