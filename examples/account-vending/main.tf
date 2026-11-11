# =============================================================================
# examples/account-vending — create workload accounts in the right OU and
# enroll them into Control Tower, so each one starts with the OU's baseline
# and guardrails already applied. Every value in this example is a placeholder.
# =============================================================================

module "accounts" {
  source = "../../organization/account/account-vending"

  accounts                        = var.accounts
  enable_control_tower_enrollment = var.enable_control_tower_enrollment
  ct_home_region                  = var.region
}

output "account_ids" {
  description = "Account IDs keyed like var.accounts"
  value       = module.accounts.account_ids
}
