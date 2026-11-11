variable "log_groups" {
  description = "Map of CloudWatch Log Groups to create"
  type = map(object({
    name              = string
    retention_in_days = optional(number, 90)
    kms_key_arn       = optional(string)
    tags              = optional(map(string), {})
  }))
  default = {}
}

variable "metric_alarms" {
  description = "Map of CloudWatch metric alarms. For simple alarms set metric_name/namespace/period/statistic. For math expressions use metric_queries."
  type = map(object({
    description         = optional(string, "")
    comparison_operator = string
    evaluation_periods  = number
    threshold           = number
    treat_missing_data  = optional(string, "missing")
    alarm_actions       = optional(list(string), [])
    ok_actions          = optional(list(string), [])

    # Simple metric (mutually exclusive with metric_queries)
    metric_name = optional(string)
    namespace   = optional(string)
    period      = optional(number)
    statistic   = optional(string, "Average")
    dimensions  = optional(map(string), {})

    # Metric math expressions
    metric_queries = optional(list(object({
      id          = string
      expression  = optional(string)
      label       = optional(string)
      return_data = optional(bool, false)
      metric = optional(object({
        metric_name = string
        namespace   = string
        period      = number
        stat        = string
        dimensions  = optional(map(string), {})
      }))
    })), [])

    tags = optional(map(string), {})
  }))
  default = {}
}

variable "dashboards" {
  description = "Map of CloudWatch dashboards. body is the JSON dashboard definition."
  type = map(object({
    body = string
  }))
  default = {}
}

variable "tags" {
  description = "Default tags applied to all resources"
  type        = map(string)
  default     = {}
}
