output "enabled_account_ids" {
  description = "Account IDs for which Inspector v2 was enabled"
  value       = aws_inspector2_enabler.this.account_ids
}

output "enabled_resource_types" {
  description = "Resource types enabled for Inspector v2 scanning"
  value       = aws_inspector2_enabler.this.resource_types
}

output "delegated_admin_account_id" {
  description = "Account ID designated as Inspector v2 delegated admin. Null if not configured."
  value       = var.delegated_admin_account_id != null ? aws_inspector2_delegated_admin_account.this[0].account_id : null
}

output "filter_arns" {
  description = "Map of filter key to ARN"
  value       = { for k, f in aws_inspector2_filter.this : k => f.arn }
}
