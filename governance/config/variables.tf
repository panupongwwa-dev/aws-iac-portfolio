variable "recorder_name" {
  description = "Name of the Config recorder and delivery channel"
  type        = string
  default     = "default"
}

# ---------------------------------------------------------------------------
# S3 bucket
# ---------------------------------------------------------------------------
variable "create_s3_bucket" {
  description = "Create the S3 bucket for Config delivery. Set false to use an existing bucket via s3_bucket_name."
  type        = bool
  default     = true
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for Config delivery (created when create_s3_bucket = true, otherwise must already exist)."
  type        = string
}

variable "force_destroy_bucket" {
  description = "Allow Terraform to delete the bucket even if it contains objects (only when create_s3_bucket = true)."
  type        = bool
  default     = false
}

variable "s3_key_prefix" {
  description = "S3 key prefix for Config delivery logs"
  type        = string
  default     = null
}

variable "log_retention_days" {
  description = "Days to retain Config history objects in S3 (0 disables the lifecycle rule). Only applies when create_s3_bucket = true."
  type        = number
  default     = 365
}

variable "kms_key_arn" {
  description = "KMS key ARN for encrypting the Config S3 bucket and SNS topic. Null uses SSE-S3 (AES256)."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# SNS topic
# ---------------------------------------------------------------------------
variable "create_sns_topic" {
  description = "Create an SNS topic for Config change notifications."
  type        = bool
  default     = false
}

variable "sns_topic_name" {
  description = "Name of the SNS topic to create (when create_sns_topic = true)."
  type        = string
  default     = "aws-config-notifications"
}

variable "sns_topic_arn" {
  description = "ARN of an existing SNS topic to deliver notifications to (when create_sns_topic = false). Null disables SNS delivery."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# IAM role
# ---------------------------------------------------------------------------
variable "create_iam_role" {
  description = "Create the IAM role assumed by AWS Config. Set false to supply an existing role via config_role_arn."
  type        = bool
  default     = true
}

variable "iam_role_name" {
  description = "Name of the IAM role to create for AWS Config (when create_iam_role = true)."
  type        = string
  default     = "aws-config-role"
}

variable "config_role_arn" {
  description = "ARN of an existing IAM role for AWS Config (required when create_iam_role = false)."
  type        = string
  default     = null
}

# ---------------------------------------------------------------------------
# Recording configuration
# ---------------------------------------------------------------------------
variable "record_all_resources" {
  description = "Record all supported resource types. When false, only resource_types are recorded."
  type        = bool
  default     = true
}

variable "resource_types" {
  description = "Specific resource types to record (used only when record_all_resources = false)."
  type        = list(string)
  default     = []
}

variable "include_global_resources" {
  description = "Include global resources (IAM) in recording. Should be true in only one region per account."
  type        = bool
  default     = true
}

variable "snapshot_delivery_frequency" {
  description = "Frequency for Config snapshots delivered to S3"
  type        = string
  default     = "TwentyFour_Hours"

  validation {
    condition     = contains(["One_Hour", "Three_Hours", "Six_Hours", "Twelve_Hours", "TwentyFour_Hours"], var.snapshot_delivery_frequency)
    error_message = "Must be one of: One_Hour, Three_Hours, Six_Hours, Twelve_Hours, TwentyFour_Hours."
  }
}

# ---------------------------------------------------------------------------
# Managed rules
# ---------------------------------------------------------------------------
variable "config_rules" {
  description = "Map of AWS managed Config rules to enable. Key is the rule name."
  type = map(object({
    description       = optional(string, "")
    source_identifier = string
    input_parameters  = optional(map(string))
  }))
  default = {}
}

variable "tags" {
  description = "Tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}
