variable "organizational_units" {
  description = "Map of OUs to create. Use parent_key to nest OUs within OUs defined in this same map."
  type = map(object({
    name       = string
    parent_id  = optional(string)
    parent_key = optional(string)
    tags       = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, ou in var.organizational_units :
      (ou.parent_id != null) != (ou.parent_key != null)
    ])
    error_message = "Each OU must have exactly one of parent_id or parent_key set."
  }

  validation {
    condition = alltrue([
      for k, ou in var.organizational_units :
      ou.parent_key == null || contains(keys(var.organizational_units), ou.parent_key)
    ])
    error_message = "parent_key must reference an existing key in the organizational_units map."
  }
}

variable "default_tags" {
  description = "Default tags applied to all OUs, merged with per-OU tags"
  type        = map(string)
  default     = {}
}
