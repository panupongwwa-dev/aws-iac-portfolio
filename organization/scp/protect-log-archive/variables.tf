variable "name" {
  description = "Name of the SCP"
  type        = string
  default     = "protect-log-archive"
}

variable "description" {
  description = "Description of the SCP"
  type        = string
  default     = "Protects CloudTrail trails, Config recorders, and log archive S3 buckets from modification or deletion"
}

variable "target_ids" {
  description = "List of account IDs, OU IDs, or Root IDs to attach this policy to"
  type        = list(string)
}

variable "log_archive_bucket_prefixes" {
  description = "S3 bucket name prefixes that identify log archive buckets. Wildcards are appended automatically."
  type        = list(string)
  default     = ["log-archive", "audit-logs", "cloudtrail-logs"]
  # Example: ["my-org-log-archive", "my-org-cloudtrail"]
}

variable "excluded_role_arns" {
  description = "IAM role ARN patterns exempt from this SCP (e.g. break-glass or log-processing automation roles). Supports wildcards."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to the policy"
  type        = map(string)
  default     = {}
}
