variable "name" {
  description = "Name of the SCP"
  type        = string
  default     = "restrict-iam-admin"
}

variable "description" {
  description = "Description of the SCP"
  type        = string
  default     = "Restricts high-risk IAM actions: blocks attaching AdministratorAccess, root credential operations, and password policy weakening"
}

variable "target_ids" {
  description = "List of account IDs, OU IDs, or Root IDs to attach this policy to"
  type        = list(string)
}

variable "excluded_role_arns" {
  description = "IAM role ARN patterns exempt from this SCP. Supports wildcards."
  type        = list(string)
  default     = []
}

variable "deny_iam_user_creation" {
  description = "Also deny creating IAM users. Enable this for accounts that should use IAM Identity Center exclusively."
  type        = bool
  default     = false
}

variable "additional_blocked_policy_arns" {
  description = "Additional managed policy ARNs to block from being attached (in addition to AdministratorAccess and IAMFullAccess)"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to the policy"
  type        = map(string)
  default     = {}
}
