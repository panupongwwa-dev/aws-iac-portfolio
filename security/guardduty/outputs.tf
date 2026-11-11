output "detector_id" {
  description = "ID of the GuardDuty detector"
  value       = aws_guardduty_detector.this.id
}

output "detector_arn" {
  description = "ARN of the GuardDuty detector"
  value       = aws_guardduty_detector.this.arn
}

output "account_id" {
  description = "AWS account ID associated with the detector"
  value       = aws_guardduty_detector.this.account_id
}

output "filter_ids" {
  description = "Map of filter key to filter ID"
  value       = { for k, f in aws_guardduty_filter.this : k => f.id }
}

output "publishing_destination_ids" {
  description = "Map of publishing destination key to resource ID"
  value       = { for k, d in aws_guardduty_publishing_destination.this : k => d.id }
}
