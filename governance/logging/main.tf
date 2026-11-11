data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

# S3 bucket for CloudTrail log archive
resource "aws_s3_bucket" "trail" {
  bucket        = var.s3_bucket_name
  force_destroy = var.force_destroy_bucket
  tags          = merge({ ManagedBy = "terraform" }, var.tags)
}

resource "aws_s3_bucket_versioning" "trail" {
  bucket = aws_s3_bucket.trail.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "trail" {
  bucket                  = aws_s3_bucket.trail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_lifecycle_configuration" "trail" {
  count  = var.log_retention_days > 0 ? 1 : 0
  bucket = aws_s3_bucket.trail.id

  rule {
    id     = "expire-cloudtrail-logs"
    status = "Enabled"

    expiration {
      days = var.log_retention_days
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

resource "aws_s3_bucket_policy" "trail" {
  bucket = aws_s3_bucket.trail.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AWSCloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.trail.arn
      },
      {
        Sid       = "AWSCloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${aws_s3_bucket.trail.arn}/AWSLogs/*"
        Condition = {
          StringEquals = {
            "s3:x-amz-acl" = "bucket-owner-full-control"
          }
        }
      }
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.trail]
}

# CloudWatch Log Group for CloudTrail
resource "aws_cloudwatch_log_group" "trail" {
  count             = var.enable_cloudwatch_logs ? 1 : 0
  name              = "/aws/cloudtrail/${var.trail_name}"
  retention_in_days = var.cloudwatch_log_retention_days
  kms_key_id        = var.kms_key_arn
  tags              = merge({ ManagedBy = "terraform" }, var.tags)
}

# IAM role allowing CloudTrail to push logs to CloudWatch
resource "aws_iam_role" "cloudtrail_cwl" {
  count = var.enable_cloudwatch_logs ? 1 : 0
  name  = "cloudtrail-cwl-${var.trail_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "cloudtrail.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge({ ManagedBy = "terraform" }, var.tags)
}

resource "aws_iam_role_policy" "cloudtrail_cwl" {
  count = var.enable_cloudwatch_logs ? 1 : 0
  name  = "cloudtrail-cwl-policy"
  role  = aws_iam_role.cloudtrail_cwl[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.trail[0].arn}:*"
    }]
  })
}

# CloudTrail
resource "aws_cloudtrail" "this" {
  name                          = var.trail_name
  s3_bucket_name                = aws_s3_bucket.trail.id
  include_global_service_events = var.include_global_events
  is_multi_region_trail         = var.is_multi_region
  is_organization_trail         = var.is_organization_trail
  enable_log_file_validation    = true
  kms_key_id                    = var.kms_key_arn

  cloud_watch_logs_group_arn = var.enable_cloudwatch_logs ? "${aws_cloudwatch_log_group.trail[0].arn}:*" : null
  cloud_watch_logs_role_arn  = var.enable_cloudwatch_logs ? aws_iam_role.cloudtrail_cwl[0].arn : null

  dynamic "event_selector" {
    for_each = var.event_selectors
    content {
      read_write_type           = event_selector.value.read_write_type
      include_management_events = event_selector.value.include_management_events

      dynamic "data_resource" {
        for_each = event_selector.value.data_resources
        content {
          type   = data_resource.value.type
          values = data_resource.value.values
        }
      }
    }
  }

  tags = merge({ ManagedBy = "terraform" }, var.tags)

  depends_on = [aws_s3_bucket_policy.trail]
}
