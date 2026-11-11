output "api_ids" {
  description = "Map of API name to API ID"
  value       = { for k, a in aws_apigatewayv2_api.this : k => a.id }
}

output "api_endpoints" {
  description = "Map of API name to default endpoint URL"
  value       = { for k, a in aws_apigatewayv2_api.this : k => a.api_endpoint }
}

output "execution_arns" {
  description = "Map of API name to execution ARN"
  value       = { for k, a in aws_apigatewayv2_api.this : k => a.execution_arn }
}

output "stage_invoke_urls" {
  description = "Map of API name to stage invoke URL"
  value       = { for k, s in aws_apigatewayv2_stage.this : k => s.invoke_url }
}

output "stage_arns" {
  description = "Map of API name to stage ARN"
  value       = { for k, s in aws_apigatewayv2_stage.this : k => s.arn }
}
