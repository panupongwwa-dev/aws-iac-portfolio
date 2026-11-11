resource "aws_budgets_budget" "this" {
  for_each = var.budgets

  name         = each.value.name
  budget_type  = each.value.budget_type
  limit_amount = each.value.limit_amount
  limit_unit   = each.value.limit_unit
  time_unit    = each.value.time_unit

  dynamic "cost_filter" {
    for_each = each.value.cost_filters
    content {
      name   = cost_filter.key
      values = cost_filter.value
    }
  }

  dynamic "notification" {
    for_each = each.value.notifications
    content {
      comparison_operator        = notification.value.comparison_operator
      threshold                  = notification.value.threshold
      threshold_type             = notification.value.threshold_type
      notification_type          = notification.value.notification_type
      subscriber_email_addresses = notification.value.subscriber_emails
      subscriber_sns_topic_arns  = notification.value.subscriber_sns_arns
    }
  }
}
