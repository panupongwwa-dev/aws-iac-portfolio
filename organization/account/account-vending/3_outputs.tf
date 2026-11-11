# 08-aws-account-vending/3_outputs.tf

output "account_ids" {
  description = "Map of all created Account IDs (use as input to other modules e.g. identity-center, security)"
  value       = { for k, v in aws_organizations_account.this : k => v.id }
}

output "account_arns" {
  description = "Map of all created Account ARNs"
  value       = { for k, v in aws_organizations_account.this : k => v.arn }
}

output "accounts_summary" {
  description = "Summary of all created accounts"
  value = {
    for k, v in aws_organizations_account.this : k => {
      id    = v.id
      name  = v.name
      email = v.email
      arn   = v.arn
    }
  }
}
