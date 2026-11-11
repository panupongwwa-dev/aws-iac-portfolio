# =============================================================================
# security/securityhub-firehose-export — Security Hub findings -> EventBridge
# -> Kinesis Firehose -> S3, for Splunk (or any other tool) to read as a
# durable, near-real-time buffer instead of polling securityhub:GetFindings.
#
# Why this exists: the direct-API poller (security/splunk-poc) calls
# GetFindings with --max-results 100 and no pagination, so any update batch
# larger than 100 findings silently drops the overflow. It also can't see
# anything that happened while the Splunk instance was stopped. EventBridge
# fires per finding create/update regardless of polling cadence, and S3
# retains everything Firehose flushes, so neither gap applies here.
#
# Runs in the Security Hub delegated-admin account: aggregated member-account
# findings are materialized into this account's own Security Hub data, so its
# default EventBridge bus receives "Security Hub Findings - Imported" events
# for ALL org findings, not just local ones — confirmed by this account's
# securityhub:GetFindings already returning member findings earlier.
# =============================================================================

data "aws_caller_identity" "current" {}

resource "aws_s3_bucket" "export" {
  bucket = "${var.name}-${data.aws_caller_identity.current.account_id}"
  tags   = merge({ ManagedBy = "terraform" }, var.tags)
}

resource "aws_s3_bucket_public_access_block" "export" {
  bucket = aws_s3_bucket.export.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "export" {
  bucket = aws_s3_bucket.export.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "export" {
  bucket = aws_s3_bucket.export.id

  rule {
    id     = "expire-old-exports"
    status = "Enabled"

    filter {}

    expiration {
      days = var.retention_days
    }
  }
}

# ---- Firehose: buffers EventBridge records and flushes them to S3 ----------

resource "aws_iam_role" "firehose" {
  name = "${var.name}-firehose"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge({ ManagedBy = "terraform" }, var.tags)
}

resource "aws_iam_role_policy" "firehose_s3" {
  name = "write-to-s3"
  role = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "FirehoseWriteExportBucket"
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetBucketLocation",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:AbortMultipartUpload",
      ]
      Resource = [
        aws_s3_bucket.export.arn,
        "${aws_s3_bucket.export.arn}/*",
      ]
    }]
  })
}

resource "aws_kinesis_firehose_delivery_stream" "this" {
  name        = var.name
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose.arn
    bucket_arn          = aws_s3_bucket.export.arn
    prefix              = "findings/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "errors/!{firehose:error-output-type}/"

    buffering_size     = var.buffer_size_mb
    buffering_interval = var.buffer_interval_seconds
    compression_format = "GZIP"
  }

  tags = merge({ ManagedBy = "terraform" }, var.tags)
}

# ---- EventBridge: catches Security Hub finding events, forwards to Firehose ----

resource "aws_cloudwatch_event_rule" "securityhub_findings" {
  name        = "${var.name}-findings"
  description = "Security Hub findings (created/updated) -> Firehose -> S3"

  event_pattern = jsonencode({
    source      = ["aws.securityhub"]
    detail-type = ["Security Hub Findings - Imported"]
  })

  tags = merge({ ManagedBy = "terraform" }, var.tags)
}

resource "aws_iam_role" "eventbridge" {
  name = "${var.name}-eventbridge"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge({ ManagedBy = "terraform" }, var.tags)
}

resource "aws_iam_role_policy" "eventbridge_firehose" {
  name = "put-records-to-firehose"
  role = aws_iam_role.eventbridge.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "PutRecordsToFirehose"
      Effect   = "Allow"
      Action   = ["firehose:PutRecord", "firehose:PutRecordBatch"]
      Resource = aws_kinesis_firehose_delivery_stream.this.arn
    }]
  })
}

resource "aws_cloudwatch_event_target" "firehose" {
  rule     = aws_cloudwatch_event_rule.securityhub_findings.name
  arn      = aws_kinesis_firehose_delivery_stream.this.arn
  role_arn = aws_iam_role.eventbridge.arn
}
