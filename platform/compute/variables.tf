variable "launch_templates" {
  description = "Map of EC2 launch templates to create"
  type = map(object({
    name                       = string
    ami_id                     = string
    instance_type              = string
    key_name                   = optional(string)
    user_data                  = optional(string)
    security_group_ids         = optional(list(string), [])
    iam_instance_profile_arn   = optional(string)
    enable_detailed_monitoring = optional(bool, false)
    root_volume = optional(object({
      size_gb     = optional(number, 20)
      type        = optional(string, "gp3")
      kms_key_arn = optional(string)
    }))
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "autoscaling_groups" {
  description = "Map of Auto Scaling Groups to create. launch_template_key must match a key in launch_templates."
  type = map(object({
    name                      = string
    launch_template_key       = string
    min_size                  = number
    max_size                  = number
    desired_capacity          = number
    subnet_ids                = list(string)
    health_check_type         = optional(string, "EC2")
    health_check_grace_period = optional(number, 300)
    tags                      = optional(map(string), {})
  }))
  default = {}
}

variable "tags" {
  description = "Default tags applied to all resources"
  type        = map(string)
  default     = {}
}
