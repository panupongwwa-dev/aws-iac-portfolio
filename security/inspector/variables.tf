variable "resource_types" {
  description = "Inspector v2 resource types to scan. Valid values: EC2, ECR, LAMBDA, LAMBDA_CODE."
  type        = list(string)
  default     = ["EC2", "ECR"]

  validation {
    condition = alltrue([
      for rt in var.resource_types :
      contains(["EC2", "ECR", "LAMBDA", "LAMBDA_CODE"], rt)
    ])
    error_message = "Each resource_type must be EC2, ECR, LAMBDA, or LAMBDA_CODE."
  }
}

variable "account_ids" {
  description = "Account IDs to enable Inspector v2 on. Defaults to the current account when empty."
  type        = list(string)
  default     = []
}

variable "member_account_ids" {
  description = <<-EOT
    Delegated-admin-only: explicitly enable Inspector v2 for these MEMBER
    account IDs (must not include the admin/calling account — AWS rejects
    mixing admin + members in one call). Use this when
    aws_inspector2_organization_configuration's auto_enable can't be set
    (e.g. an SCP blocks inspector2:UpdateOrganizationConfiguration) —
    inspector2:Enable is a separate, often-unblocked action.
  EOT
  type        = list(string)
  default     = []
}

variable "delegated_admin_account_id" {
  description = "Account ID to designate as Inspector v2 delegated admin. Run from the management account."
  type        = string
  default     = null
}

variable "is_delegated_admin" {
  description = "Whether this account is the Inspector v2 delegated admin. Enables org-wide auto-enable configuration."
  type        = bool
  default     = false
}

variable "auto_enable" {
  description = "Inspector v2 resource types to auto-enable for new organization member accounts. Only used when is_delegated_admin = true."
  type = object({
    ec2         = optional(bool, true)
    ecr         = optional(bool, true)
    lambda      = optional(bool, false)
    lambda_code = optional(bool, false)
  })
  default = {}
}

variable "filters" {
  description = "Map of Inspector v2 suppression filters"
  type = map(object({
    description = optional(string, "")
    action      = string
    criteria = object({
      aws_account_ids = optional(list(object({
        comparison = string
        value      = string
      })), [])
      severities = optional(list(object({
        comparison = string
        value      = string
      })), [])
      resource_types = optional(list(object({
        comparison = string
        value      = string
      })), [])
      finding_statuses = optional(list(object({
        comparison = string
        value      = string
      })), [])
      ecr_image_tags = optional(list(object({
        comparison = string
        value      = string
      })), [])
      vulnerability_ids = optional(list(object({
        comparison = string
        value      = string
      })), [])
    })
    tags = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.filters : contains(["SUPPRESS", "NONE"], v.action)
    ])
    error_message = "Filter action must be SUPPRESS or NONE."
  }
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
