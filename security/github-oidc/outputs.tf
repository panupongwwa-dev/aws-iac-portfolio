output "oidc_provider_arn" {
  description = "ARN of the GitHub Actions OIDC provider"
  value       = local.oidc_provider_arn
}

output "role_arns" {
  description = "Map of role name to ARN — use as role-to-assume in GitHub Actions"
  value       = { for k, r in aws_iam_role.this : k => r.arn }
}
