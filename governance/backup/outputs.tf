output "vault_id" {
  description = "ID of the backup vault"
  value       = aws_backup_vault.this.id
}

output "vault_arn" {
  description = "ARN of the backup vault"
  value       = aws_backup_vault.this.arn
}

output "backup_plan_ids" {
  description = "Map of backup plan key to plan ID"
  value       = { for k, p in aws_backup_plan.this : k => p.id }
}

output "backup_plan_arns" {
  description = "Map of backup plan key to plan ARN"
  value       = { for k, p in aws_backup_plan.this : k => p.arn }
}
