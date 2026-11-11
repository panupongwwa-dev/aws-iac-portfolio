output "secret_ids" {
  description = "Map of secret key to secret ID (ARN)"
  value       = { for k, s in aws_secretsmanager_secret.this : k => s.id }
}

output "secret_arns" {
  description = "Map of secret key to ARN"
  value       = { for k, s in aws_secretsmanager_secret.this : k => s.arn }
}

output "secret_names" {
  description = "Map of secret key to secret name"
  value       = { for k, s in aws_secretsmanager_secret.this : k => s.name }
}
