output "destination_arn" {
  description = "ARN of the CloudWatch Logs Destination — point cross-account subscription filters at this"
  value       = aws_cloudwatch_log_destination.this.arn
}

output "bucket_name" {
  description = "S3 bucket name where centralized logs land"
  value       = aws_s3_bucket.central_logs.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.central_logs.arn
}

output "sqs_queue_arn" {
  description = "SQS queue ARN that receives S3 ObjectCreated notifications for new log files — for TA-aws's SQS-based S3 input"
  value       = aws_sqs_queue.s3_notifications.arn
}

output "sqs_queue_url" {
  description = "SQS queue URL — same queue as sqs_queue_arn"
  value       = aws_sqs_queue.s3_notifications.url
}
