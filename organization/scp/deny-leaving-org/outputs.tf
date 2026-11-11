output "id" {
  description = "ID of the SCP"
  value       = aws_organizations_policy.this.id
}

output "arn" {
  description = "ARN of the SCP"
  value       = aws_organizations_policy.this.arn
}

output "name" {
  description = "Name of the SCP"
  value       = aws_organizations_policy.this.name
}
