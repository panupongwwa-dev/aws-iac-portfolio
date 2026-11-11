variable "budgets" {
  description = "Map of budgets to create. Key is a local identifier."
  type = map(object({
    name         = string
    budget_type  = optional(string, "COST")
    limit_amount = string
    limit_unit   = optional(string, "USD")
    time_unit    = optional(string, "MONTHLY")
    cost_filters = optional(map(list(string)), {})
    notifications = optional(list(object({
      comparison_operator = optional(string, "GREATER_THAN")
      threshold           = number
      threshold_type      = optional(string, "PERCENTAGE")
      notification_type   = optional(string, "ACTUAL")
      subscriber_emails   = optional(list(string), [])
      subscriber_sns_arns = optional(list(string), [])
    })), [])
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, b in var.budgets :
      contains(["COST", "USAGE", "RI_UTILIZATION", "RI_COVERAGE", "SAVINGS_PLANS_UTILIZATION", "SAVINGS_PLANS_COVERAGE"], b.budget_type)
    ])
    error_message = "budget_type must be one of: COST, USAGE, RI_UTILIZATION, RI_COVERAGE, SAVINGS_PLANS_UTILIZATION, SAVINGS_PLANS_COVERAGE."
  }

  validation {
    condition = alltrue([
      for k, b in var.budgets :
      contains(["DAILY", "MONTHLY", "QUARTERLY", "ANNUALLY"], b.time_unit)
    ])
    error_message = "time_unit must be one of: DAILY, MONTHLY, QUARTERLY, ANNUALLY."
  }
}
