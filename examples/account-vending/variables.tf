variable "region" {
  description = "Control Tower home region"
  type        = string
}

variable "accounts" {
  description = "Accounts to create and enroll into Control Tower"
  type = map(object({
    name        = string
    email       = string
    ou_id       = string
    environment = string
    tags        = map(string)
  }))
}

variable "enable_control_tower_enrollment" {
  description = "Enroll each new account into Control Tower by re-registering its OU"
  type        = bool
  default     = true
}
