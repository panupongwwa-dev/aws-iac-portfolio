output "trail_id" {
  description = "ID of the CloudTrail trail"
  value       = aws_cloudtrail.this.id
}

output "trail_arn" {
  description = "ARN of the CloudTrail trail"
  value       = aws_cloudtrail.this.arn
}

output "trail_home_region" {
  description = "Region in which the trail was created"
  value       = aws_cloudtrail.this.home_region
}

output "s3_bucket_id" {
  description = "ID of the S3 bucket for CloudTrail logs"
  value       = aws_s3_bucket.trail.id
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket for CloudTrail logs"
  value       = aws_s3_bucket.trail.arn
}

output "cloudwatch_log_group_name" {
  description = "Name of the CloudWatch log group for CloudTrail. Null if enable_cloudwatch_logs is false."
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.trail[0].name : null
}

output "cloudwatch_log_group_arn" {
  description = "ARN of the CloudWatch log group for CloudTrail. Null if enable_cloudwatch_logs is false."
  value       = var.enable_cloudwatch_logs ? aws_cloudwatch_log_group.trail[0].arn : null
}
