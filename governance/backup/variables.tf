variable "vault_name" {
  description = "Name of the backup vault"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN to encrypt backups. Defaults to AWS managed key when null."
  type        = string
  default     = null
}

variable "vault_lock" {
  description = "WORM lock for compliance mode. Once changeable_for_days elapses, cannot be removed."
  type = object({
    changeable_for_days = optional(number, 3)
    min_retention_days  = number
    max_retention_days  = number
  })
  default = null

  validation {
    condition     = var.vault_lock == null || var.vault_lock.changeable_for_days >= 3
    error_message = "changeable_for_days must be at least 3."
  }

  validation {
    condition     = var.vault_lock == null || var.vault_lock.min_retention_days <= var.vault_lock.max_retention_days
    error_message = "min_retention_days must be less than or equal to max_retention_days."
  }
}

variable "backup_role_arn" {
  description = "IAM role ARN for AWS Backup resource selection. Defaults to AWSBackupDefaultServiceRole."
  type        = string
  default     = null
}

variable "backup_plans" {
  description = "Map of backup plans to create"
  type = map(object({
    name = string
    rules = list(object({
      name                     = string
      schedule                 = string
      start_window             = optional(number, 60)
      completion_window        = optional(number, 180)
      enable_continuous_backup = optional(bool, false)
      lifecycle = optional(object({
        cold_storage_after = optional(number)
        delete_after       = number
      }))
    }))
    selection_tags = optional(map(string), {})
    tags           = optional(map(string), {})
  }))
  default = {}
}

variable "tags" {
  description = "Default tags applied to all resources"
  type        = map(string)
  default     = {}
}
