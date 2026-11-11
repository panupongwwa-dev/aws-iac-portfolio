output "queue_ids" {
  description = "Map of queue key to SQS queue URL"
  value       = { for k, q in aws_sqs_queue.this : k => q.id }
}

output "queue_arns" {
  description = "Map of queue key to SQS queue ARN"
  value       = { for k, q in aws_sqs_queue.this : k => q.arn }
}

output "dlq_arns" {
  description = "Map of DLQ key to ARN"
  value       = { for k, q in aws_sqs_queue.dlq : k => q.arn }
}

output "topic_arns" {
  description = "Map of topic key to SNS topic ARN"
  value       = { for k, t in aws_sns_topic.this : k => t.arn }
}

output "topic_ids" {
  description = "Map of topic key to SNS topic ID"
  value       = { for k, t in aws_sns_topic.this : k => t.id }
}
