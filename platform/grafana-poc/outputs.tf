output "instance_id" {
  description = "EC2 instance ID (use with: aws ssm start-session --target <id>)"
  value       = aws_instance.grafana.id
}

output "public_ip" {
  description = "Public IP — Grafana UI at http://<public_ip>:3000"
  value       = aws_instance.grafana.public_ip
}

output "admin_password_secret_arn" {
  description = "Secrets Manager ARN holding the auto-generated Grafana admin password"
  value       = aws_secretsmanager_secret.grafana_admin.arn
}

output "iam_role_arn" {
  description = "IAM role attached to the instance"
  value       = aws_iam_role.grafana.arn
}
