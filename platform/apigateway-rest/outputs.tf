output "rest_api_ids" {
  description = "Map of API name to REST API ID"
  value       = { for k, a in aws_api_gateway_rest_api.this : k => a.id }
}

output "execution_arns" {
  description = "Map of API name to execution ARN"
  value       = { for k, a in aws_api_gateway_rest_api.this : k => a.execution_arn }
}

output "invoke_urls" {
  description = "Map of API name to stage invoke URL"
  value       = { for k, s in aws_api_gateway_stage.this : k => s.invoke_url }
}

output "stage_arns" {
  description = "Map of API name to stage ARN — pass to the waf module's associate_resource_arns"
  value       = { for k, s in aws_api_gateway_stage.this : k => s.arn }
}
