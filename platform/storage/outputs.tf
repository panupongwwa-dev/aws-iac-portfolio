output "bucket_ids" {
  description = "Map of bucket key to bucket name/ID"
  value       = { for k, b in aws_s3_bucket.this : k => b.id }
}

output "bucket_arns" {
  description = "Map of bucket key to ARN"
  value       = { for k, b in aws_s3_bucket.this : k => b.arn }
}

output "bucket_domain_names" {
  description = "Map of bucket key to bucket domain name"
  value       = { for k, b in aws_s3_bucket.this : k => b.bucket_domain_name }
}

output "bucket_regional_domain_names" {
  description = "Map of bucket key to regional domain name"
  value       = { for k, b in aws_s3_bucket.this : k => b.bucket_regional_domain_name }
}
