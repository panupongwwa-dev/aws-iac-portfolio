output "sso_instance_arn" {
  description = "ARN of the SSO instance"
  value       = local.sso_instance_arn
}

output "identity_store_id" {
  description = "ID of the Identity Store"
  value       = local.identity_store_id
}

output "permission_set_arns" {
  description = "Map of permission set key to ARN"
  value       = { for k, ps in aws_ssoadmin_permission_set.this : k => ps.arn }
}

output "permission_set_names" {
  description = "Map of permission set key to name"
  value       = { for k, ps in aws_ssoadmin_permission_set.this : k => ps.name }
}
