variable "db_subnet_groups" {
  description = "Map of RDS subnet groups to create"
  type = map(object({
    subnet_ids = list(string)
    tags       = optional(map(string), {})
  }))
  default = {}
}

variable "db_parameter_groups" {
  description = "Map of RDS parameter groups to create"
  type = map(object({
    family     = string
    parameters = optional(map(string), {})
    tags       = optional(map(string), {})
  }))
  default = {}
}

variable "db_instances" {
  description = "Map of RDS instances to create"
  type = map(object({
    engine         = string
    engine_version = string
    instance_class = string

    allocated_storage     = number
    max_allocated_storage = optional(number)
    storage_type          = optional(string, "gp3")
    kms_key_arn           = optional(string)

    db_name  = optional(string)
    username = string
    # Set password to null to use manage_master_user_password (AWS Secrets Manager)
    password = optional(string)

    subnet_group_key     = optional(string)
    subnet_group_name    = optional(string)
    parameter_group_key  = optional(string)
    parameter_group_name = optional(string)
    security_group_ids   = optional(list(string), [])

    multi_az                = optional(bool, false)
    deletion_protection     = optional(bool, true)
    skip_final_snapshot     = optional(bool, false)
    backup_retention_period = optional(number, 7)
    backup_window           = optional(string, "03:00-04:00")
    maintenance_window      = optional(string, "Mon:04:00-Mon:05:00")

    tags = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, db in var.db_instances :
      (db.subnet_group_key != null) != (db.subnet_group_name != null) ||
      (db.subnet_group_key == null && db.subnet_group_name == null)
    ])
    error_message = "Each db_instance must have exactly one of subnet_group_key or subnet_group_name."
  }
}

variable "tags" {
  description = "Default tags applied to all resources"
  type        = map(string)
  default     = {}
}
