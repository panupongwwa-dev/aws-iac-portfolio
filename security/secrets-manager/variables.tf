variable "secrets" {
  description = "Map of secrets to create. Initial values should be set outside Terraform (e.g., via CLI or application) to avoid storing sensitive data in state."
  type = map(object({
    name                    = string
    description             = optional(string, "")
    kms_key_arn             = optional(string)
    recovery_window_in_days = optional(number, 30)

    replica_regions = optional(list(object({
      region      = string
      kms_key_arn = optional(string)
    })), [])

    rotation = optional(object({
      lambda_arn               = string
      automatically_after_days = optional(number)
      duration                 = optional(string)
      schedule_expression      = optional(string)
    }))

    tags = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.secrets :
      v.recovery_window_in_days == 0 ||
      (v.recovery_window_in_days >= 7 && v.recovery_window_in_days <= 30)
    ])
    error_message = "recovery_window_in_days must be 0 (force delete) or between 7 and 30."
  }
}

variable "tags" {
  description = "Default tags applied to all resources"
  type        = map(string)
  default     = {}
}
