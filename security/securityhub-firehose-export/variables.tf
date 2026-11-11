variable "name" {
  description = "Name prefix for the S3 bucket, Firehose stream, and EventBridge rule"
  type        = string
  default     = "securityhub-export"
}

variable "buffer_interval_seconds" {
  description = "Firehose buffering hint: max seconds before flushing to S3 (lower = fresher data in S3, more/smaller objects)"
  type        = number
  default     = 60
}

variable "buffer_size_mb" {
  description = "Firehose buffering hint: max MB before flushing to S3"
  type        = number
  default     = 1
}

variable "retention_days" {
  description = "S3 lifecycle: expire exported findings after this many days"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}
