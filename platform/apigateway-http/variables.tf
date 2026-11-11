variable "apis" {
  description = "Map of HTTP APIs (API Gateway v2). Key = API name."
  type = map(object({
    description = optional(string, "")

    cors = optional(object({
      allow_origins = optional(list(string), ["*"])
      allow_methods = optional(list(string), ["*"])
      allow_headers = optional(list(string), ["*"])
      max_age       = optional(number, 0)
    }))

    # routes: key = route_key like "GET /items" or "$default"
    routes = map(object({
      lambda_invoke_arn      = string # from lambda module output invoke_arns
      lambda_function_name   = string # from lambda module output function_names
      payload_format_version = optional(string, "2.0")
      authorization_type     = optional(string, "NONE")
    }))

    stage_name             = optional(string, "$default")
    auto_deploy            = optional(bool, true)
    throttling_burst_limit = optional(number)
    throttling_rate_limit  = optional(number)

    access_log_destination_arn = optional(string) # CloudWatch Logs log group ARN

    tags = optional(map(string), {})
  }))
  default = {}
}

variable "tags" {
  description = "Tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}
