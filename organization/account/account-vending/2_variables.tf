# 08-aws-account-vending/2_variables.tf

variable "accounts" {
  description = "Map of AWS Accounts to create in the Organization"
  type = map(object({
    name        = string      # Display name shown in AWS Console
    email       = string      # Root email (must be unique across all accounts in the org)
    ou_id       = string      # Target OU ID, e.g. "ou-examplerootid111-exampleouid111"
    environment = string      # e.g. "dev", "staging", "prod"
    tags        = map(string) # Additional tags
  }))
  default = {}
}

variable "enable_control_tower_enrollment" {
  description = "Enable Control Tower enrollment after account creation (requires CT v3.3+)"
  type        = bool
  default     = true
}

variable "ct_home_region" {
  description = "Region where Control Tower is deployed"
  type        = string
  default     = "ap-southeast-7"
}

variable "ct_baseline_arn" {
  description = "ARN of the AWSControlTowerBaseline in the home region (aws controltower list-baselines)"
  type        = string
  default     = "arn:aws:controltower:ap-southeast-7::baseline/17BSJV3IGJ2QSGA2"
}

variable "ct_baseline_version" {
  description = "Baseline version to enable — must match the version enabled on the target's OU (aws controltower list-enabled-baselines)"
  type        = string
  default     = "5.0"
}

variable "identity_center_enabled_baseline_arn" {
  description = "ARN of the org's ENABLED IdentityCenterBaseline (aws controltower list-enabled-baselines) — required as an EnableBaseline parameter when the landing zone uses Identity Center"
  type        = string
  default     = ""
}

variable "ou_controls" {
  description = "Map of CT Guardrails to apply on OUs"
  type = map(object({
    ou_arn       = string       # OU ARN, e.g. "arn:aws:organizations::123456789012:ou/o-xxx/ou-xxx-xxx"
    control_arns = list(string) # List of Control ARNs to enable
  }))
  default = {}
}
