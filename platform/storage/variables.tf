variable "buckets" {
  description = "Map of S3 buckets to create"
  type = map(object({
    name                = string
    versioning          = optional(bool, true)
    intelligent_tiering = optional(bool, false)
    force_destroy       = optional(bool, false)
    kms_key_arn         = optional(string)
    lifecycle_rules = optional(list(object({
      id                                 = string
      enabled                            = optional(bool, true)
      expiration_days                    = optional(number)
      noncurrent_version_expiration_days = optional(number)
      transitions = optional(list(object({
        days          = number
        storage_class = string
      })), [])
    })), [])
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "tags" {
  description = "Default tags applied to all resources"
  type        = map(string)
  default     = {}
}
