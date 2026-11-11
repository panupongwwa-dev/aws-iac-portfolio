variable "apis" {
  description = <<-EOT
    Map of REST APIs (API Gateway v1). Key = API name.
    Each API is wired as a Lambda-proxy catch-all (ANY / and ANY /{proxy+}),
    which suits PHP frameworks / Bref that route internally.
    Use endpoint_type = "REGIONAL" so a REGIONAL WAF Web ACL can attach to the stage.
  EOT
  type = map(object({
    description   = optional(string, "")
    endpoint_type = optional(string, "REGIONAL") # REGIONAL (WAF-attachable) | EDGE | PRIVATE

    lambda_invoke_arn    = string # from lambda module output invoke_arns
    lambda_function_name = string # from lambda module output function_names

    stage_name       = optional(string, "prod")
    api_key_required = optional(bool, false)

    throttling_burst_limit = optional(number)
    throttling_rate_limit  = optional(number)

    access_log_destination_arn = optional(string) # CloudWatch Logs log group ARN

    tags = optional(map(string), {})
  }))
  default = {}

  validation {
    condition     = alltrue([for k, v in var.apis : contains(["REGIONAL", "EDGE", "PRIVATE"], v.endpoint_type)])
    error_message = "endpoint_type must be REGIONAL, EDGE, or PRIVATE."
  }
}

variable "tags" {
  description = "Tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}
