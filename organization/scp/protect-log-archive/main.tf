data "aws_partition" "current" {}

locals {
  exclusion = length(var.excluded_role_arns) > 0 ? {
    Condition = {
      StringNotLike = {
        "aws:PrincipalARN" = var.excluded_role_arns
      }
    }
  } : {}

  # Build S3 resource ARNs for the log archive bucket pattern
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
        Sid    = "DenyConfigRecorderModification"
        Effect = "Deny"
        Action = [
          "config:DeleteConfigRule",
          "config:DeleteConfigurationRecorder",
          "config:DeleteDeliveryChannel",
          "config:StopConfigurationRecorder",
          "config:PutConfigurationRecorder"
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
      }, local.exclusion)
    ]
  })
}

resource "aws_organizations_policy_attachment" "this" {
  for_each  = toset(var.target_ids)
  policy_id = aws_organizations_policy.this.id
  target_id = each.value
}
