variable "name" {
  description = "Name of the SCP"
  type        = string
  default     = "deny-leaving-org"
}

variable "description" {
  description = "Description of the SCP"
  type        = string
  default     = "Prevents member accounts from leaving the AWS Organization"
}

variable "target_ids" {
  description = "List of account IDs, OU IDs, or Root IDs to attach this policy to"
  type        = list(string)
}

variable "tags" {
  description = "Tags applied to the policy"
  type        = map(string)
  default     = {}
}
