# Merges deny-leaving-org + protect-log-archive + protect-security-services
# into one policy - same statements, just consolidated so each target OU only
# spends 1 SCP slot instead of 3 against AWS's per-target attachment quota.
data "aws_partition" "current" {}

locals {
  exclusion = length(var.excluded_role_arns) > 0 ? {
    Condition = {
      StringNotLike = {
        "aws:PrincipalARN" = var.excluded_role_arns
      }
    }
  } : {}

  log_archive_s3_resources = flatten([
    for prefix in var.log_archive_bucket_prefixes : [
      "arn:${data.aws_partition.current.partition}:s3:::${prefix}*",
      "arn:${data.aws_partition.current.partition}:s3:::${prefix}*/*"
    ]
  ])
}

resource "aws_organizations_policy" "this" {
  name        = var.name
  description = var.description
  type        = "SERVICE_CONTROL_POLICY"
  tags        = merge({ ManagedBy = "terraform" }, var.tags)

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyLeavingOrganization"
        Effect   = "Deny"
        Action   = ["organizations:LeaveOrganization"]
        Resource = ["*"]
      },

      merge({
        Sid    = "DenyCloudTrailModification"
        Effect = "Deny"
        Action = [
          "cloudtrail:DeleteTrail",
          "cloudtrail:StopLogging",
          "cloudtrail:UpdateTrail",
          "cloudtrail:PutEventSelectors",
          "cloudtrail:PutInsightSelectors",
          "cloudtrail:RemoveTags",
          "cloudtrail:DeleteEventDataStore"
        ]
        Resource = ["*"]
      }, local.exclusion),

      merge({
        Sid    = "DenyConfigModification"
        Effect = "Deny"
        Action = [
          "config:DeleteConfigRule",
          "config:DeleteConfigurationRecorder",
          "config:DeleteDeliveryChannel",
          "config:StopConfigurationRecorder",
          "config:PutConfigurationRecorder",
          "config:DeleteOrganizationConfigRule",
          "config:DeleteOrganizationConformancePack"
        ]
        Resource = ["*"]
      }, local.exclusion),

      merge({
        Sid    = "DenyLogArchiveBucketModification"
        Effect = "Deny"
        Action = [
          "s3:DeleteBucket",
          "s3:DeleteBucketPolicy",
          "s3:PutBucketPolicy",
          "s3:PutLifecycleConfiguration",
          "s3:PutEncryptionConfiguration",
          "s3:PutBucketVersioning",
          "s3:PutBucketLogging",
          "s3:DeleteObject",
          "s3:DeleteObjectVersion"
        ]
        Resource = local.log_archive_s3_resources
      }, local.exclusion),

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
