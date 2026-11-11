variable "name" {
  description = "Name of the Service Control Policy"
  type        = string
}

variable "description" {
  description = "Description of the policy"
  type        = string
  default     = ""
}

variable "content" {
  description = "Policy document in JSON format (use jsonencode or file())"
  type        = string
}

variable "policy_type" {
  description = "Type of policy (SERVICE_CONTROL_POLICY, TAG_POLICY, BACKUP_POLICY, AISERVICES_OPT_OUT_POLICY)"
  type        = string
  default     = "SERVICE_CONTROL_POLICY"

  validation {
    condition = contains([
      "SERVICE_CONTROL_POLICY",
      "TAG_POLICY",
      "BACKUP_POLICY",
      "AISERVICES_OPT_OUT_POLICY"
    ], var.policy_type)
    error_message = "Invalid policy type."
  }
}

variable "target_ids" {
  description = "List of account IDs, OU IDs, or Root IDs to attach this policy to"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to the policy"
  type        = map(string)
  default     = {}
}
