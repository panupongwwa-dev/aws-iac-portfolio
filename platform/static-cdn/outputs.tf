output "distribution_id" {
  description = "CloudFront distribution ID — needed for cache invalidations in the deploy pipeline"
  value       = aws_cloudfront_distribution.this.id
}

output "domain_name" {
  description = "CloudFront distribution domain (the new entry point users should use instead of the raw API Gateway invoke URL)"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "static_bucket_name" {
  description = "S3 bucket name — the deploy pipeline syncs assets/vendors here"
  value       = aws_s3_bucket.static.id
}

output "static_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.static.arn
}
