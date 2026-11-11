# --- GuardDuty ---

variable "enable_guardduty" {
  description = "Enable GuardDuty detector in this account/region"
  type        = bool
  default     = true
}

variable "guardduty_s3_logs" {
  description = "Enable GuardDuty S3 data event monitoring"
  type        = bool
  default     = true
}

variable "guardduty_kubernetes_audit_logs" {
  description = "Enable GuardDuty Kubernetes audit log monitoring"
  type        = bool
  default     = false
}

variable "guardduty_malware_protection" {
  description = "Enable GuardDuty malware protection (EBS volume scanning)"
  type        = bool
  default     = false
}

variable "is_guardduty_delegated_admin" {
  description = "Whether this account is the GuardDuty delegated administrator. Enables organization-wide auto-enable."
  type        = bool
  default     = false
}

variable "guardduty_auto_enable_org_members" {
  description = "Auto-enable GuardDuty for new organization member accounts (ALL, NEW, NONE)"
  type        = string
  default     = "NEW"

  validation {
    condition     = contains(["ALL", "NEW", "NONE"], var.guardduty_auto_enable_org_members)
    error_message = "Must be ALL, NEW, or NONE."
  }
}

# --- Security Hub ---

variable "enable_security_hub" {
  description = "Enable Security Hub in this account"
  type        = bool
  default     = true
}

variable "securityhub_enable_default_standards" {
  description = "Enable the default Security Hub standards on account enrollment"
  type        = bool
  default     = false
}

variable "securityhub_auto_enable_controls" {
  description = "Automatically enable new controls added to enabled standards"
  type        = bool
  default     = true
}

variable "securityhub_standards_arns" {
  description = <<-EOT
    Map of standards to subscribe to. Key is a local label, value is the full region-specific standard ARN.
    ARN format: arn:aws:securityhub:<region>::standards/<standard>/v/<version>
    Common values:
      aws_foundational_security = "arn:aws:securityhub:ap-southeast-1::standards/aws-foundational-security-best-practices/v/1.0.0"
      cis_aws_1_4               = "arn:aws:securityhub:ap-southeast-1::standards/cis-aws-foundations-benchmark/v/1.4.0"
      nist_800_53               = "arn:aws:securityhub:ap-southeast-1::standards/nist-800-53/v/5.0.0"
  EOT
  type        = map(string)
  default     = {}
}

variable "is_securityhub_delegated_admin" {
  description = "Whether this account is the Security Hub delegated administrator"
  type        = bool
  default     = false
}

variable "securityhub_auto_enable_org_members" {
  description = "Auto-enable Security Hub for new organization member accounts"
  type        = bool
  default     = true
}

variable "securityhub_auto_enable_org_standards" {
  description = "Auto-enable default standards for new organization member accounts"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
