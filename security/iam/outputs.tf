output "role_arns" {
  description = "Map of role name to ARN"
  value       = { for k, r in aws_iam_role.this : k => r.arn }
}

output "role_names" {
  description = "Map of role key to role name"
  value       = { for k, r in aws_iam_role.this : k => r.name }
}

output "instance_profile_arns" {
  description = "Map of role key to instance profile ARN (only for roles with create_instance_profile = true)"
  value       = { for k, p in aws_iam_instance_profile.this : k => p.arn }
}

output "instance_profile_names" {
  description = "Map of role key to instance profile name"
  value       = { for k, p in aws_iam_instance_profile.this : k => p.name }
}

output "policy_arns" {
  description = "Map of policy key to ARN"
  value       = { for k, p in aws_iam_policy.this : k => p.arn }
}
