variable "name" {
  description = "Name of the SCP"
  type        = string
  default     = "protect-security-services"
}

variable "description" {
  description = "Description of the SCP"
  type        = string
  default     = "Prevents disabling or modifying GuardDuty, Security Hub, Config, Inspector, and Access Analyzer"
}

variable "target_ids" {
  description = "List of account IDs, OU IDs, or Root IDs to attach this policy to"
  type        = list(string)
}

variable "excluded_role_arns" {
  description = "IAM role ARN patterns exempt from this SCP (e.g. break-glass or automation roles). Supports wildcards."
  type        = list(string)
  default     = []
  # Example: ["arn:aws:iam::*:role/BreakGlass*", "arn:aws:iam::*:role/SecurityAutomation"]
}

variable "tags" {
  description = "Tags applied to the policy"
  type        = map(string)
  default     = {}
}
