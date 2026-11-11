variable "name" {
  description = "Name of the SCP"
  type        = string
  default     = "deny-rds-deletion"
}

variable "description" {
  description = "Description of the SCP"
  type        = string
  default     = "Denies deletion of RDS/Aurora instances, clusters, and snapshots"
}

variable "target_ids" {
  description = "List of account IDs, OU IDs, or Root IDs to attach this policy to"
  type        = list(string)
}

variable "excluded_role_arns" {
  description = "IAM role ARN patterns exempt from this SCP (e.g. DBA break-glass role). Supports wildcards."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to the policy"
  type        = map(string)
  default     = {}
}
