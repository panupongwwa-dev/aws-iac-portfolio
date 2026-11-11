resource "aws_cloudwatch_log_group" "this" {
  for_each = var.log_groups

  name              = each.value.name
  retention_in_days = each.value.retention_in_days
  kms_key_id        = each.value.kms_key_arn
  tags              = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)
}

resource "aws_cloudwatch_metric_alarm" "this" {
  for_each = var.metric_alarms

  alarm_name          = each.key
  alarm_description   = each.value.description
  comparison_operator = each.value.comparison_operator
  evaluation_periods  = each.value.evaluation_periods
  threshold           = each.value.threshold
  treat_missing_data  = each.value.treat_missing_data

  alarm_actions = each.value.alarm_actions
  ok_actions    = each.value.ok_actions

  # Simple metric (single metric without math expression)
  dynamic "metric_query" {
    for_each = length(each.value.metric_queries) > 0 ? each.value.metric_queries : []
    content {
      id          = metric_query.value.id
      expression  = metric_query.value.expression
      label       = metric_query.value.label
      return_data = metric_query.value.return_data

      dynamic "metric" {
        for_each = metric_query.value.metric != null ? [metric_query.value.metric] : []
        content {
          metric_name = metric.value.metric_name
          namespace   = metric.value.namespace
          period      = metric.value.period
          stat        = metric.value.stat
          dimensions  = metric.value.dimensions
        }
      }
    }
  }

  # Simple single-metric alarm (no metric_queries)
  metric_name = length(each.value.metric_queries) == 0 ? each.value.metric_name : null
  namespace   = length(each.value.metric_queries) == 0 ? each.value.namespace : null
  period      = length(each.value.metric_queries) == 0 ? each.value.period : null
  statistic   = length(each.value.metric_queries) == 0 ? each.value.statistic : null
  dimensions  = length(each.value.metric_queries) == 0 ? each.value.dimensions : null

  tags = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)
}

resource "aws_cloudwatch_dashboard" "this" {
  for_each       = var.dashboards
  dashboard_name = each.key
  dashboard_body = each.value.body
}
