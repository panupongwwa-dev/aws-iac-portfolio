output "repository_urls" {
  description = "Map of repo name to URI (use as the base for lambda image_uri: <url>:<tag>)"
  value       = { for k, r in aws_ecr_repository.this : k => r.repository_url }
}

output "repository_arns" {
  description = "Map of repo name to ARN"
  value       = { for k, r in aws_ecr_repository.this : k => r.arn }
}

output "repository_names" {
  description = "Map of repo key to repository name"
  value       = { for k, r in aws_ecr_repository.this : k => r.name }
}
