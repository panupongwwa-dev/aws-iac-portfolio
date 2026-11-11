output "recorder_id" {
  description = "ID of the Config recorder"
  value       = aws_config_configuration_recorder.this.id
}

output "recorder_name" {
  description = "Name of the Config recorder"
  value       = aws_config_configuration_recorder.this.name
}

output "delivery_channel_id" {
  description = "ID of the delivery channel"
  value       = aws_config_delivery_channel.this.id
}

output "role_arn" {
  description = "ARN of the IAM role used by AWS Config"
  value       = local.role_arn
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket used for Config delivery"
  value       = var.create_s3_bucket ? aws_s3_bucket.config[0].id : var.s3_bucket_name
}

output "s3_bucket_arn" {
  description = "ARN of the S3 bucket used for Config delivery"
  value       = local.bucket_arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for Config notifications (null if not configured)"
  value       = local.sns_topic_arn
}

output "config_rule_arns" {
  description = "Map of Config rule name to ARN"
  value       = { for k, r in aws_config_config_rule.this : k => r.arn }
}

output "config_rule_ids" {
  description = "Map of Config rule name to ID"
  value       = { for k, r in aws_config_config_rule.this : k => r.id }
}
