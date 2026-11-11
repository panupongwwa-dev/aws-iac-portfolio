variable "permission_sets" {
  description = "Map of IAM Identity Center permission sets to create"
  type = map(object({
    description         = optional(string, "")
    session_duration    = optional(string, "PT8H")
    inline_policy       = optional(string)
    managed_policy_arns = optional(list(string), [])
    tags                = optional(map(string), {})
  }))
  default = {}
}

variable "account_assignments" {
  description = "Map of account assignments. permission_set_key must match a key in permission_sets. principal_type is USER or GROUP."
  type = map(object({
    permission_set_key = string
    principal_id       = string
    principal_type     = string
    account_id         = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.account_assignments :
      contains(["USER", "GROUP"], v.principal_type)
    ])
    error_message = "principal_type must be USER or GROUP."
  }
}

variable "tags" {
  description = "Default tags applied to all resources"
  type        = map(string)
  default     = {}
}
