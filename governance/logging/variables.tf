variable "trail_name" {
  description = "Name of the CloudTrail trail"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket to create for CloudTrail log archive"
  type        = string
}

variable "force_destroy_bucket" {
  description = "Allow Terraform to delete the S3 bucket even if it contains objects (use for dev/test only)"
  type        = bool
  default     = false
}

variable "log_retention_days" {
  description = "Days to retain CloudTrail logs in S3. Set to 0 to disable lifecycle expiry."
  type        = number
  default     = 365
}

variable "is_multi_region" {
  description = "Record API calls from all regions into a single trail"
  type        = bool
  default     = true
}

variable "is_organization_trail" {
  description = "Create an organization-level trail. Requires execution from the management account."
  type        = bool
  default     = false
}

variable "include_global_events" {
  description = "Include global service events such as IAM and STS"
  type        = bool
  default     = true
}

variable "enable_cloudwatch_logs" {
  description = "Stream CloudTrail events to a CloudWatch Logs group"
  type        = bool
  default     = true
}

variable "cloudwatch_log_retention_days" {
  description = "Retention period in days for the CloudWatch Logs group"
  type        = number
  default     = 90
}

variable "kms_key_arn" {
  description = "KMS key ARN to encrypt CloudTrail log files and CloudWatch log group"
  type        = string
  default     = null
}

variable "event_selectors" {
  description = "Event selectors for logging data events (e.g. S3 object-level, Lambda invocations)"
  type = list(object({
    read_write_type           = optional(string, "All")
    include_management_events = optional(bool, true)
    data_resources = optional(list(object({
      type   = string
      values = list(string)
    })), [])
  }))
  default = []
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
