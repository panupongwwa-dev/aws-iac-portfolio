output "budget_ids" {
  description = "Map of budget key to budget ID"
  value       = { for k, b in aws_budgets_budget.this : k => b.id }
}

output "budget_arns" {
  description = "Map of budget key to budget ARN"
  value       = { for k, b in aws_budgets_budget.this : k => b.arn }
}
