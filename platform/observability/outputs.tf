output "log_group_names" {
  description = "Map of log group key to log group name"
  value       = { for k, lg in aws_cloudwatch_log_group.this : k => lg.name }
}

output "log_group_arns" {
  description = "Map of log group key to ARN"
  value       = { for k, lg in aws_cloudwatch_log_group.this : k => lg.arn }
}

output "metric_alarm_arns" {
  description = "Map of alarm key to ARN"
  value       = { for k, a in aws_cloudwatch_metric_alarm.this : k => a.arn }
}

output "dashboard_arns" {
  description = "Map of dashboard key to ARN"
  value       = { for k, d in aws_cloudwatch_dashboard.this : k => d.dashboard_arn }
}
