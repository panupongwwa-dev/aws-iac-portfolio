output "securityhub_id" {
  description = "ID of the Security Hub account subscription"
  value       = aws_securityhub_account.this.id
}

output "standards_subscription_arns" {
  description = "Map of standard label to subscription ARN"
  value       = { for k, s in aws_securityhub_standards_subscription.this : k => s.id }
}

output "finding_aggregator_arn" {
  description = "ARN of the finding aggregator. Null if not configured."
  value       = var.finding_aggregator != null ? aws_securityhub_finding_aggregator.this[0].id : null
}

output "insight_arns" {
  description = "Map of insight key to ARN"
  value       = { for k, i in aws_securityhub_insight.this : k => i.arn }
}

output "action_target_arns" {
  description = "Map of action target key to ARN"
  value       = { for k, a in aws_securityhub_action_target.this : k => a.arn }
}
