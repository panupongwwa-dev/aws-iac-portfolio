variable "keys" {
  description = "Map of KMS keys to create"
  type = map(object({
    description             = optional(string, "")
    key_usage               = optional(string, "ENCRYPT_DECRYPT")
    key_spec                = optional(string, "SYMMETRIC_DEFAULT")
    enable_rotation         = optional(bool, true)
    rotation_period_in_days = optional(number, 365)
    deletion_window_in_days = optional(number, 30)
    alias                   = optional(string)

    # Custom policy JSON. When null, a default policy is generated from admin_arns/user_arns/service_principals.
    policy = optional(string)

    # Used to generate the default key policy (ignored when policy is set)
    admin_arns         = optional(list(string), [])
    user_arns          = optional(list(string), [])
    service_principals = optional(list(string), [])

    tags = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.keys :
      contains(["ENCRYPT_DECRYPT", "SIGN_VERIFY", "GENERATE_VERIFY_MAC"], v.key_usage)
    ])
    error_message = "key_usage must be ENCRYPT_DECRYPT, SIGN_VERIFY, or GENERATE_VERIFY_MAC."
  }

  validation {
    condition = alltrue([
      for k, v in var.keys :
      v.deletion_window_in_days >= 7 && v.deletion_window_in_days <= 30
    ])
    error_message = "deletion_window_in_days must be between 7 and 30."
  }
}

variable "tags" {
  description = "Default tags applied to all resources"
  type        = map(string)
  default     = {}
}
