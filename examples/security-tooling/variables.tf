variable "region" {
  description = "Region the security services run in"
  type        = string
}

variable "inspector_member_account_ids" {
  description = "Workload accounts to enable Inspector in explicitly (see the note in main.tf)"
  type        = list(string)
  default     = []
}

variable "central_log_sources" {
  description = "Workload log groups allowed to stream into the central log archive"
  type = list(object({
    account_id             = string
    region                 = string
    log_group_name_pattern = string
  }))
  default = []
}

variable "tags" {
  description = "Default tags applied to every resource"
  type        = map(string)
  default     = {}
}
