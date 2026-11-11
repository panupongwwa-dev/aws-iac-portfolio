variable "name" {
  description = "Name prefix for the S3 bucket, Firehose stream, and Logs Destination"
  type        = string
  default     = "cw-logs-central"
}

variable "source_log_groups" {
  description = "Log groups (in other accounts) allowed to subscribe to the Logs Destination. Only account_id is actually used (the destination policy grants by account, not per log group) — region/log_group_name_pattern are kept for documentation of what's expected to subscribe."
  type = list(object({
    account_id             = string
    region                 = string
    log_group_name_pattern = string
  }))
  default = []
}

variable "buffer_interval_seconds" {
  description = "Firehose buffering hint: max seconds before flushing to S3"
  type        = number
  default     = 60
}

variable "buffer_size_mb" {
  description = "Firehose buffering hint: max MB before flushing to S3"
  type        = number
  default     = 1
}

variable "retention_days" {
  description = "S3 lifecycle: expire centralized logs after this many days"
  type        = number
  default     = 90
}

variable "tags" {
  description = "Tags applied to all resources created by this module"
  type        = map(string)
  default     = {}
}
