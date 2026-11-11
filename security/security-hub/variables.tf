variable "enable_default_standards" {
  description = "Enable the default Security Hub standards on account enrollment. Recommended: false — subscribe explicitly via standards_arns."
  type        = bool
  default     = false
}

variable "auto_enable_controls" {
  description = "Automatically enable new controls added to subscribed standards"
  type        = bool
  default     = true
}

variable "control_finding_generator" {
  description = "Finding generator mode: STANDARD_CONTROL (one finding per control per resource) or SECURITY_CONTROL (consolidated view)"
  type        = string
  default     = "SECURITY_CONTROL"

  validation {
    condition     = contains(["STANDARD_CONTROL", "SECURITY_CONTROL"], var.control_finding_generator)
    error_message = "Must be STANDARD_CONTROL or SECURITY_CONTROL."
  }
}

variable "standards_arns" {
  description = "Map of label → standard ARN to subscribe to. ARNs are region-specific — use data.aws_region.current to build them."
  type        = map(string)
  default     = {}
  # Example:
  # standards_arns = {
  #   fsbp  = "arn:aws:securityhub:ap-southeast-7::standards/aws-foundational-security-best-practices/v/1.0.0"
  #   cis14 = "arn:aws:securityhub:ap-southeast-7::standards/cis-aws-foundations-benchmark/v/1.4.0"
  #   pci   = "arn:aws:securityhub:ap-southeast-7::standards/pci-dss/v/3.2.1"
  #   nist  = "arn:aws:securityhub:ap-southeast-7::standards/nist-800-53/v/5.0.0"
  # }
}

variable "finding_aggregator" {
  description = "Cross-region finding aggregation configuration. Set to enable aggregating findings from all/specified regions."
  type = object({
    linking_mode      = string
    specified_regions = optional(list(string), [])
  })
  default = null

  validation {
    condition = var.finding_aggregator == null || contains(
      ["ALL_REGIONS", "ALL_REGIONS_EXCEPT_SPECIFIED", "SPECIFIED_REGIONS"],
      var.finding_aggregator.linking_mode
    )
    error_message = "linking_mode must be ALL_REGIONS, ALL_REGIONS_EXCEPT_SPECIFIED, or SPECIFIED_REGIONS."
  }
}

variable "is_delegated_admin" {
  description = "Whether this account is the Security Hub delegated administrator. Enables org-wide configuration."
  type        = bool
  default     = false
}

variable "auto_enable_org_members" {
  description = "Auto-enable Security Hub for new organization member accounts. Only used when is_delegated_admin = true."
  type        = bool
  default     = true
}

variable "auto_enable_org_standards" {
  description = "Auto-enable default standards for new member accounts. Only used when is_delegated_admin = true."
  type        = bool
  default     = false
}

variable "insights" {
  description = "Map of custom Security Hub insights (saved finding queries)"
  type = map(object({
    group_by_attribute = string
    filters = object({
      severity_labels   = optional(list(string), [])
      workflow_statuses = optional(list(string), [])
      record_states     = optional(list(string), [])
      product_names     = optional(list(string), [])
    })
  }))
  default = {}
}

variable "action_targets" {
  description = "Map of custom action targets for Security Hub integrations (e.g. send to Jira via EventBridge)"
  type = map(object({
    identifier  = string
    description = string
  }))
  default = {}
}
