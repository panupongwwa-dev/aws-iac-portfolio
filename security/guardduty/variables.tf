variable "enable" {
  description = "Enable the GuardDuty detector"
  type        = bool
  default     = true
}

variable "finding_publishing_frequency" {
  description = "Frequency for publishing findings to SNS/S3 (FIFTEEN_MINUTES, ONE_HOUR, SIX_HOURS)"
  type        = string
  default     = "SIX_HOURS"

  validation {
    condition     = contains(["FIFTEEN_MINUTES", "ONE_HOUR", "SIX_HOURS"], var.finding_publishing_frequency)
    error_message = "Must be FIFTEEN_MINUTES, ONE_HOUR, or SIX_HOURS."
  }
}

variable "datasources" {
  description = "GuardDuty data sources to enable"
  type = object({
    s3_logs               = optional(bool, true)
    kubernetes_audit_logs = optional(bool, false)
    malware_protection    = optional(bool, false)
  })
  default = {}
}

variable "is_delegated_admin" {
  description = "Whether this account is the GuardDuty delegated administrator. Enables org-wide configuration."
  type        = bool
  default     = false
}

variable "auto_enable_org_members" {
  description = "Auto-enable GuardDuty for organization members (ALL, NEW, NONE). Only used when is_delegated_admin = true."
  type        = string
  default     = "NEW"

  validation {
    condition     = contains(["ALL", "NEW", "NONE"], var.auto_enable_org_members)
    error_message = "Must be ALL, NEW, or NONE."
  }
}

variable "filters" {
  description = "Map of GuardDuty suppression/archive filters. criteria keys are GuardDuty finding fields."
  type = map(object({
    action = string
    rank   = number
    criteria = map(object({
      equals                = optional(list(string))
      not_equals            = optional(list(string))
      greater_than          = optional(string)
      greater_than_or_equal = optional(string)
      less_than             = optional(string)
      less_than_or_equal    = optional(string)
    }))
    tags = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.filters : contains(["ARCHIVE", "NOOP"], v.action)
    ])
    error_message = "Filter action must be ARCHIVE or NOOP."
  }
}

variable "publishing_destinations" {
  description = "Map of finding export destinations (S3 bucket or EventBridge)"
  type = map(object({
    destination_arn  = string
    destination_type = optional(string, "S3")
    kms_key_arn      = optional(string)
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.publishing_destinations : contains(["S3"], v.destination_type)
    ])
    error_message = "destination_type must be S3."
  }
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
