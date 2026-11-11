variable "region" {
  description = "Home region of the organization management stack"
  type        = string
}

variable "ous" {
  description = "Organizational units that receive guardrails: short name => OU ID"
  type        = map(string)

  validation {
    condition     = alltrue([for k in ["development", "production", "security"] : contains(keys(var.ous), k)])
    error_message = "ous must define development, production and security."
  }
}

variable "tags" {
  description = "Default tags applied to every SCP this stack creates"
  type        = map(string)
  default     = {}
}
