output "bucket_name" {
  description = "S3 bucket name where exported findings land — grant readers s3:GetObject/ListBucket here"
  value       = aws_s3_bucket.export.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.export.arn
}

output "firehose_arn" {
  description = "Kinesis Firehose delivery stream ARN"
  value       = aws_kinesis_firehose_delivery_stream.this.arn
}
