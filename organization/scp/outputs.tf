output "id" {
  description = "ID of the policy"
  value       = aws_organizations_policy.this.id
}

output "arn" {
  description = "ARN of the policy"
  value       = aws_organizations_policy.this.arn
}

output "name" {
  description = "Name of the policy"
  value       = aws_organizations_policy.this.name
}

output "type" {
  description = "Type of the policy"
  value       = aws_organizations_policy.this.type
}
