output "function_arns" {
  description = "Map of function name to ARN"
  value       = { for k, f in aws_lambda_function.this : k => f.arn }
}

output "function_names" {
  description = "Map of function key to deployed function name"
  value       = { for k, f in aws_lambda_function.this : k => f.function_name }
}

output "invoke_arns" {
  description = "Map of function name to invoke ARN (use as API Gateway integration_uri)"
  value       = { for k, f in aws_lambda_function.this : k => f.invoke_arn }
}

output "role_arns" {
  description = "Map of function name to execution role ARN"
  value       = { for k, r in aws_iam_role.this : k => r.arn }
}

output "log_group_names" {
  description = "Map of function name to CloudWatch log group name"
  value       = { for k, g in aws_cloudwatch_log_group.this : k => g.name }
}

output "alias_arns" {
  description = "Map of function key to the 'live' alias ARN — only present for functions with publish = true"
  value       = { for k, a in aws_lambda_alias.live : k => a.arn }
}
