output "instance_id" {
  description = "EC2 instance ID (use with: aws ssm start-session --target <id>)"
  value       = aws_instance.splunk.id
}

output "public_ip" {
  description = "Public IP — Splunk Web UI at https://<public_ip>:8000"
  value       = aws_instance.splunk.public_ip
}

output "admin_password_secret_arn" {
  description = "Secrets Manager ARN holding the auto-generated Splunk admin password"
  value       = aws_secretsmanager_secret.splunk_admin.arn
}

output "iam_role_arn" {
  description = "IAM role attached to the instance (has securityhub:GetFindings + SSM)"
  value       = aws_iam_role.splunk.arn
}

output "app_bundles_bucket_name" {
  description = "S3 bucket for installer bundles the instance can't fetch directly (e.g. TA-aws) — upload with: aws s3 cp <file> s3://<this>/apps/"
  value       = aws_s3_bucket.app_bundles.bucket
}
