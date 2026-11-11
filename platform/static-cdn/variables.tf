variable "name" {
  description = "Name prefix for the S3 bucket and CloudFront distribution"
  type        = string
}

variable "api_gateway_domain_name" {
  description = "API Gateway custom domain to use as the dynamic origin, e.g. \"abc123.execute-api.ap-southeast-7.amazonaws.com\""
  type        = string
}

variable "api_gateway_origin_path" {
  description = "Path CloudFront prepends before forwarding to the API Gateway origin, e.g. \"/dev\" (the stage name)"
  type        = string
}

variable "static_path_patterns" {
  description = "CloudFront path patterns routed to the S3 origin instead of the API Gateway origin, e.g. [\"/assets/*\", \"/vendors/*\"]"
  type        = list(string)
  default     = ["/assets/*", "/vendors/*"]
}

variable "price_class" {
  description = "CloudFront price class. PriceClass_100 = US/Canada/Europe only — doesn't cover Asia edge locations, so users in Southeast Asia wouldn't get a local edge cache hit. PriceClass_200 adds Asia/Africa/Oceania."
  type        = string
  default     = "PriceClass_200"
}

variable "static_cache_min_ttl" {
  description = "Min TTL (seconds) for cached static assets"
  type        = number
  default     = 3600
}

variable "static_cache_default_ttl" {
  description = "Default TTL (seconds) for cached static assets — applies when the origin doesn't send cache headers"
  type        = number
  default     = 86400
}

variable "static_cache_max_ttl" {
  description = "Max TTL (seconds) for cached static assets"
  type        = number
  default     = 31536000
}

variable "aliases" {
  description = "Custom domain names (CNAMEs) the distribution answers for. Requires acm_certificate_arn. Additive — the default *.cloudfront.net domain keeps working."
  type        = list(string)
  default     = []
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN covering every name in aliases. MUST be issued in us-east-1 and in the same account as the distribution (CloudFront requirements). Empty = default *.cloudfront.net certificate."
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}
