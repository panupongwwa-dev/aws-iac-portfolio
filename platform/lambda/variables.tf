variable "functions" {
  description = "Map of Lambda functions to create. Key = function name."
  type = map(object({
    description   = optional(string, "")
    architectures = optional(list(string), ["x86_64"])

    # ---- packaging: provide EITHER a zip (filename / s3) OR a container image ----
    runtime          = optional(string) # required for zip packages (e.g. "python3.12")
    handler          = optional(string) # required for zip packages (e.g. "app.handler")
    filename         = optional(string) # path to local .zip
    source_code_hash = optional(string) # base64sha256 of the zip (triggers updates)
    s3_bucket        = optional(string)
    s3_key           = optional(string)
    image_uri        = optional(string) # ECR image URI (sets package_type = Image)

    # ---- sizing ----
    memory_size                    = optional(number, 128)
    timeout                        = optional(number, 3)
    ephemeral_storage_mb           = optional(number, 512)
    reserved_concurrent_executions = optional(number, -1)

    # ---- config ----
    environment_variables = optional(map(string), {})
    layers                = optional(list(string), [])
    tracing_mode          = optional(string) # "Active" | "PassThrough"

    # Publishes a numbered version on every code change and points a "live"
    # alias at it (main.tf's aws_lambda_alias.live) — required for
    # Provisioned Concurrency, which AWS refuses to attach to $LATEST.
    # Defaults false so every existing function (unqualified $LATEST,
    # invoked directly by ARN) is unaffected; a caller that turns this on
    # must also switch whatever invokes the function (e.g. an API Gateway
    # integration_uri) over to this module's alias_arns output, or the new
    # version/alias just sits unused.
    publish = optional(bool, false)

    # ---- networking (optional) ----
    vpc_config = optional(object({
      subnet_ids         = list(string)
      security_group_ids = list(string)
    }))

    # ---- IAM ----
    managed_policy_arns = optional(list(string), [])
    inline_policy_json  = optional(string)

    # ---- logs / encryption ----
    log_retention_days = optional(number, 14)
    kms_key_arn        = optional(string)

    tags = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.functions :
      v.image_uri != null || (v.runtime != null && v.handler != null)
    ])
    error_message = "Each function needs either image_uri, or both runtime and handler (for zip packages)."
  }
}

variable "tags" {
  description = "Tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}
