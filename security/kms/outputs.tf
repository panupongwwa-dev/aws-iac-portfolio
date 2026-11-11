output "key_ids" {
  description = "Map of key name to KMS key ID"
  value       = { for k, key in aws_kms_key.this : k => key.key_id }
}

output "key_arns" {
  description = "Map of key name to KMS key ARN"
  value       = { for k, key in aws_kms_key.this : k => key.arn }
}

output "alias_arns" {
  description = "Map of key name to KMS alias ARN (only keys with alias set)"
  value       = { for k, a in aws_kms_alias.this : k => a.arn }
}

output "alias_names" {
  description = "Map of key name to KMS alias name"
  value       = { for k, a in aws_kms_alias.this : k => a.name }
}
