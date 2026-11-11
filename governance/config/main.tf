data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  partition  = data.aws_partition.current.partition

  bucket_arn = var.create_s3_bucket ? aws_s3_bucket.config[0].arn : "arn:${local.partition}:s3:::${var.s3_bucket_name}"
  role_arn   = var.create_iam_role ? aws_iam_role.config[0].arn : var.config_role_arn

  sns_topic_arn = var.create_sns_topic ? aws_sns_topic.config[0].arn : var.sns_topic_arn
}

# ---------------------------------------------------------------------------
# S3 bucket for Config snapshots / configuration history
# ---------------------------------------------------------------------------
resource "aws_s3_bucket" "config" {
  count         = var.create_s3_bucket ? 1 : 0
  bucket        = var.s3_bucket_name
  force_destroy = var.force_destroy_bucket
  tags          = merge({ ManagedBy = "terraform" }, var.tags)
}

resource "aws_s3_bucket_versioning" "config" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.config[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "config" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.config[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = var.kms_key_arn != null
  }
}

resource "aws_s3_bucket_public_access_block" "config" {
  count                   = var.create_s3_bucket ? 1 : 0
  bucket                  = aws_s3_bucket.config[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "config" {
  count  = var.create_s3_bucket && var.log_retention_days > 0 ? 1 : 0
  bucket = aws_s3_bucket.config[0].id

  rule {
    id     = "expire-config-history"
    status = "Enabled"

    filter {}

    expiration {
      days = var.log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# Bucket policy granting AWS Config the permissions it needs to deliver data
resource "aws_s3_bucket_policy" "config" {
  count  = var.create_s3_bucket ? 1 : 0
  bucket = aws_s3_bucket.config[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSConfigBucketPermissionsCheck"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.config[0].arn
        Condition = { StringEquals = { "AWS:SourceAccount" = local.account_id } }
      },
      {
        Sid       = "AWSConfigBucketExistenceCheck"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:ListBucket"
        Resource  = aws_s3_bucket.config[0].arn
        Condition = { StringEquals = { "AWS:SourceAccount" = local.account_id } }
      },
      {
        Sid       = "AWSConfigBucketDelivery"
        Effect    = "Allow"
        Principal = { Service = "config.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.config[0].arn}/AWSLogs/${local.account_id}/Config/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"      = "bucket-owner-full-control"
            "AWS:SourceAccount" = local.account_id
          }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource = [
          aws_s3_bucket.config[0].arn,
          "${aws_s3_bucket.config[0].arn}/*"
        ]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.config]
}

# ---------------------------------------------------------------------------
# SNS topic for Config change notifications (optional)
# ---------------------------------------------------------------------------
resource "aws_sns_topic" "config" {
  count             = var.create_sns_topic ? 1 : 0
  name              = var.sns_topic_name
  kms_master_key_id = var.kms_key_arn
  tags              = merge({ ManagedBy = "terraform" }, var.tags)
}

resource "aws_sns_topic_policy" "config" {
  count = var.create_sns_topic ? 1 : 0
  arn   = aws_sns_topic.config[0].arn

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AWSConfigSNSPublish"
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "SNS:Publish"
      Resource  = aws_sns_topic.config[0].arn
      Condition = { StringEquals = { "AWS:SourceAccount" = local.account_id } }
    }]
  })
}

# ---------------------------------------------------------------------------
# IAM role assumed by AWS Config
# ---------------------------------------------------------------------------
resource "aws_iam_role" "config" {
  count = var.create_iam_role ? 1 : 0
  name  = var.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "config.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "AWS:SourceAccount" = local.account_id } }
    }]
  })

  tags = merge({ ManagedBy = "terraform" }, var.tags)
}

# AWS managed policy that grants Config read access to all resource types
resource "aws_iam_role_policy_attachment" "config_managed" {
  count      = var.create_iam_role ? 1 : 0
  role       = aws_iam_role.config[0].name
  policy_arn = "arn:${local.partition}:iam::aws:policy/service-role/AWS_ConfigRole"
}

# Inline policy granting delivery to the S3 bucket (and SNS topic if used)
resource "aws_iam_role_policy" "config_delivery" {
  count = var.create_iam_role ? 1 : 0
  name  = "config-delivery"
  role  = aws_iam_role.config[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid      = "AllowBucketAcl"
          Effect   = "Allow"
          Action   = ["s3:GetBucketAcl", "s3:ListBucket"]
          Resource = local.bucket_arn
        },
        {
          Sid      = "AllowPutObject"
          Effect   = "Allow"
          Action   = "s3:PutObject"
          Resource = "${local.bucket_arn}/AWSLogs/${local.account_id}/Config/*"
          Condition = {
            StringEquals = { "s3:x-amz-acl" = "bucket-owner-full-control" }
          }
        }
      ],
      local.sns_topic_arn != null ? [{
        Sid      = "AllowSNSPublish"
        Effect   = "Allow"
        Action   = "SNS:Publish"
        Resource = local.sns_topic_arn
      }] : []
    )
  })
}

# ---------------------------------------------------------------------------
# Config recorder, delivery channel and status
# ---------------------------------------------------------------------------
resource "aws_config_configuration_recorder" "this" {
  name     = var.recorder_name
  role_arn = local.role_arn

  recording_group {
    all_supported                 = var.record_all_resources
    include_global_resource_types = var.record_all_resources ? var.include_global_resources : false
    resource_types                = var.record_all_resources ? null : var.resource_types
  }

  depends_on = [aws_iam_role_policy_attachment.config_managed]
}

resource "aws_config_delivery_channel" "this" {
  name           = var.recorder_name
  s3_bucket_name = var.create_s3_bucket ? aws_s3_bucket.config[0].id : var.s3_bucket_name
  s3_key_prefix  = var.s3_key_prefix
  sns_topic_arn  = local.sns_topic_arn

  snapshot_delivery_properties {
    delivery_frequency = var.snapshot_delivery_frequency
  }

  depends_on = [
    aws_config_configuration_recorder.this,
    aws_s3_bucket_policy.config
  ]
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.this]
}

# ---------------------------------------------------------------------------
# AWS managed Config rules
# ---------------------------------------------------------------------------
resource "aws_config_config_rule" "this" {
  for_each = var.config_rules

  name        = each.key
  description = each.value.description

  source {
    owner             = "AWS"
    source_identifier = each.value.source_identifier
  }

  input_parameters = each.value.input_parameters != null ? jsonencode(each.value.input_parameters) : null

  tags = merge({ ManagedBy = "terraform" }, var.tags)

  depends_on = [aws_config_configuration_recorder_status.this]
}
