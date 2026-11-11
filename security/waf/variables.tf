variable "web_acls" {
  description = "Map of WAFv2 Web ACLs. Key = Web ACL name."
  type = map(object({
    description = optional(string, "")

    # REGIONAL = ALB / API Gateway REST / AppSync; CLOUDFRONT = CloudFront (must be us-east-1)
    scope = optional(string, "REGIONAL")

    # default action for requests that match no rule
    default_action = optional(string, "allow") # "allow" | "block"

    # AWS / marketplace managed rule groups
    managed_rule_groups = optional(list(object({
      name            = string # e.g. "AWSManagedRulesCommonRuleSet"
      vendor_name     = optional(string, "AWS")
      priority        = number
      override_action = optional(string, "none") # "none" applies the group; "count" only counts
    })), [])

    # rate-based (per-IP) rules
    rate_based_rules = optional(list(object({
      name          = string
      priority      = number
      limit         = number                 # requests per 5-minute window. NOTE: ap-southeast-7 rejects < 100 (WAFInvalidOperationException) even though AWS's documented global minimum is 10 — confirmed via direct testing 2026-06-19.
      aggregate_key = optional(string, "IP") # IP | FORWARDED_IP
    })), [])

    # Allow-list by country: blocks any request whose source country is NOT
    # in country_codes (ISO 3166-1 alpha-2, e.g. "TH"). null = no geo restriction.
    geo_allow_rule = optional(object({
      name          = optional(string, "geo-allow-list")
      priority      = number
      country_codes = list(string)
    }))

    cloudwatch_metrics_enabled = optional(bool, true)
    sampled_requests_enabled   = optional(bool, true)

    # Logging: set retention_days to enable WAF logs → CloudWatch Logs
    log_retention_days = optional(number) # null = logging disabled

    # REGIONAL only: resource ARNs to associate (e.g. ALB / REST API stage).
    # NOTE: HTTP API (apigatewayv2) and CloudFront are NOT associated here.
    associate_resource_arns = optional(list(string), [])

    tags = optional(map(string), {})
  }))
  default = {}

  validation {
    condition     = alltrue([for k, v in var.web_acls : contains(["REGIONAL", "CLOUDFRONT"], v.scope)])
    error_message = "scope must be REGIONAL or CLOUDFRONT."
  }

  validation {
    condition     = alltrue([for k, v in var.web_acls : contains(["allow", "block"], v.default_action)])
    error_message = "default_action must be allow or block."
  }

  validation {
    condition     = alltrue([for k, v in var.web_acls : alltrue([for r in v.rate_based_rules : r.limit >= 100])])
    error_message = "rate_based_rules limit must be >= 100 — some regions (e.g. ap-southeast-7) reject lower values despite AWS's documented global minimum of 10."
  }
}

variable "tags" {
  description = "Tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}
