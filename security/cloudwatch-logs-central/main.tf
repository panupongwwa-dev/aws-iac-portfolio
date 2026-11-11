# =============================================================================
# security/cloudwatch-logs-central — cross-account CloudWatch Logs
# centralization. Each source account (dev/staging/prod) attaches a
# Subscription Filter to a CloudWatch Logs "Destination" that lives in THIS
# (aggregator) account, which forwards to Kinesis Firehose -> S3.
#
# Lambda-as-target was tried first and rejected: AWS still requires a
# Destination+DestinationPolicy for cross-account Lambda subscription
# filters too ("Cross-account lambda invocation passing is not allowed");
# there's no simpler resource-permission-only path for Lambda either. Given
# that, Firehose is the better target anyway — built for exactly this
# buffer-and-flush-to-S3 job, no per-log-event invocation cost.
#
# Firehose's own compression is left UNCOMPRESSED on purpose. Each
# CloudWatch Logs record arriving here is already an independent,
# self-contained gzip stream (the standard CWL subscription format); Firehose
# just concatenates whatever bytes it's given before flushing to S3. Relying
# on Firehose's built-in CloudWatch-decompression processor instead would
# work too, but Terraform provider support for it has been inconsistent
# across versions — simpler and more predictable to decompress client-side.
# Python's gzip.decompress() already handles concatenated multi-stream gzip
# data, and each decompressed member is a standalone JSON document, so the
# Splunk-side poller parses them the same way it already does for the
# Security Hub Firehose export (json.JSONDecoder().raw_decode() in a loop).
# =============================================================================

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_s3_bucket" "central_logs" {
  bucket = "${var.name}-${data.aws_caller_identity.current.account_id}"
  tags   = merge({ ManagedBy = "terraform" }, var.tags)
}

resource "aws_s3_bucket_public_access_block" "central_logs" {
  bucket = aws_s3_bucket.central_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "central_logs" {
  bucket = aws_s3_bucket.central_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "central_logs" {
  bucket = aws_s3_bucket.central_logs.id

  rule {
    id     = "expire-old-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = var.retention_days
    }
  }
}

# ---- Firehose: buffers incoming log records and flushes them to S3 --------

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
      Sid    = "FirehoseWriteCentralLogsBucket"
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:GetBucketLocation",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:AbortMultipartUpload",
      ]
      Resource = [
        aws_s3_bucket.central_logs.arn,
        "${aws_s3_bucket.central_logs.arn}/*",
      ]
    }]
  })
}

resource "aws_kinesis_firehose_delivery_stream" "this" {
  name        = var.name
  destination = "extended_s3"

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose.arn
    bucket_arn          = aws_s3_bucket.central_logs.arn
    prefix              = "logs/year=!{timestamp:yyyy}/month=!{timestamp:MM}/day=!{timestamp:dd}/"
    error_output_prefix = "errors/!{firehose:error-output-type}/"
    buffering_size      = var.buffer_size_mb
    buffering_interval  = var.buffer_interval_seconds
    compression_format  = "UNCOMPRESSED" # records are already individually gzip'd by CWL — see header note
  }

  tags = merge({ ManagedBy = "terraform" }, var.tags)
}

# ---- CloudWatch Logs Destination: the cross-account entry point -----------

resource "aws_iam_role" "logs_destination" {
  name = "${var.name}-logs-destination"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "logs.${data.aws_region.current.name}.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge({ ManagedBy = "terraform" }, var.tags)
}

resource "aws_iam_role_policy" "logs_destination_firehose" {
  name = "put-records-to-firehose"
  role = aws_iam_role.logs_destination.id

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

resource "aws_cloudwatch_log_destination" "this" {
  name       = var.name
  role_arn   = aws_iam_role.logs_destination.arn
  target_arn = aws_kinesis_firehose_delivery_stream.this.arn
}

# Resource policy: lets the listed source accounts attach subscription
# filters to this destination from their own log groups.
resource "aws_cloudwatch_log_destination_policy" "this" {
  destination_name = aws_cloudwatch_log_destination.this.name

  access_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "AllowSourceAccountsSubscribe"
      Effect = "Allow"
      Principal = {
        # AWS CloudWatch Logs Destination policies want bare account IDs here,
        # not full IAM ARNs — confirmed via InvalidParameterException
        # ("Principal section of policy contains ARN instead of account ID")
        # when this used "arn:aws:iam::<id>:root" like a normal resource policy.
        AWS = distinct([for lg in var.source_log_groups : lg.account_id])
      }
      Action   = "logs:PutSubscriptionFilter"
      Resource = aws_cloudwatch_log_destination.this.arn
    }]
  })
}

# ---- SQS notification on new objects: lets Splunk's TA-aws "SQS-based S3"
# input pick up new files without polling S3 itself. NOTE: each record in
# these objects is still an independently gzip-compressed CloudWatch Logs
# subscription blob, concatenated with no delimiter (see header note) — TA-aws
# may or may not parse that automatically; this is a deliberate experiment,
# not a guaranteed-working path. ----------------------------------------------

resource "aws_sqs_queue" "s3_notifications" {
  name                      = "${var.name}-s3-notifications"
  message_retention_seconds = 345600 # 4 days — plenty for a low-volume poller to catch up after downtime

  tags = merge({ ManagedBy = "terraform" }, var.tags)
}

resource "aws_sqs_queue_policy" "s3_notifications" {
  queue_url = aws_sqs_queue.s3_notifications.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCentralLogsBucketToSendMessages"
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sqs:SendMessage"
      Resource  = aws_sqs_queue.s3_notifications.arn
      Condition = {
        ArnEquals    = { "aws:SourceArn" = aws_s3_bucket.central_logs.arn }
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
      }
    }]
  })
}

resource "aws_s3_bucket_notification" "central_logs" {
  bucket = aws_s3_bucket.central_logs.id

  queue {
    queue_arn     = aws_sqs_queue.s3_notifications.arn
    events        = ["s3:ObjectCreated:*"]
    filter_prefix = "logs/"
  }

  depends_on = [aws_sqs_queue_policy.s3_notifications]
}
