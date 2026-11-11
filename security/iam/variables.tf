variable "roles" {
  description = "Map of IAM roles to create. policy_keys references keys in var.policies; managed_policy_arns accepts AWS ARNs directly."
  type = map(object({
    description             = optional(string, "")
    path                    = optional(string, "/")
    max_session_duration    = optional(number, 3600)
    create_instance_profile = optional(bool, false)
    trust_policy_statements = list(object({
      Effect    = string
      Principal = any
      Action    = any
      Condition = optional(any)
    }))
    policy_keys         = optional(list(string), [])
    managed_policy_arns = optional(list(string), [])
    tags                = optional(map(string), {})
  }))
  default = {}
}

variable "policies" {
  description = "Map of IAM policies to create. policy_json is the policy document as a JSON string (use jsonencode)."
  type = map(object({
    description = optional(string, "")
    path        = optional(string, "/")
    policy_json = string
    tags        = optional(map(string), {})
  }))
  default = {}
}

variable "tags" {
  description = "Default tags applied to all resources"
  type        = map(string)
  default     = {}
}
