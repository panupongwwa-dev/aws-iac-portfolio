output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector. Null if enable_guardduty is false."
  value       = one(aws_guardduty_detector.this[*].id)
}

output "guardduty_detector_arn" {
  description = "ARN of the GuardDuty detector. Null if enable_guardduty is false."
  value       = one(aws_guardduty_detector.this[*].arn)
}

output "securityhub_id" {
  description = "ID of the Security Hub account subscription. Null if enable_security_hub is false."
  value       = one(aws_securityhub_account.this[*].id)
}

output "securityhub_standards_arns" {
  description = "Map of subscribed standard keys to standard ARNs"
  value       = { for k, s in aws_securityhub_standards_subscription.this : k => s.id }
}
