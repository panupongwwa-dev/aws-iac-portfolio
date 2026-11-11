data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

resource "aws_backup_vault" "this" {
  name        = var.vault_name
  kms_key_arn = var.kms_key_arn
  tags        = merge({ ManagedBy = "terraform" }, var.tags)
}

resource "aws_backup_vault_lock_configuration" "this" {
  count = var.vault_lock != null ? 1 : 0

  backup_vault_name   = aws_backup_vault.this.name
  changeable_for_days = var.vault_lock.changeable_for_days
  min_retention_days  = var.vault_lock.min_retention_days
  max_retention_days  = var.vault_lock.max_retention_days
}

resource "aws_backup_plan" "this" {
  for_each = var.backup_plans

  name = each.value.name

  dynamic "rule" {
    for_each = each.value.rules
    content {
      rule_name                = rule.value.name
      target_vault_name        = aws_backup_vault.this.name
      schedule                 = rule.value.schedule
      start_window             = rule.value.start_window
      completion_window        = rule.value.completion_window
      enable_continuous_backup = rule.value.enable_continuous_backup

      dynamic "lifecycle" {
        for_each = rule.value.lifecycle != null ? [rule.value.lifecycle] : []
        content {
          cold_storage_after = lifecycle.value.cold_storage_after
          delete_after       = lifecycle.value.delete_after
        }
      }
    }
  }

  tags = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)
}

resource "aws_backup_selection" "this" {
  for_each = {
    for k, plan in var.backup_plans : k => plan
    if length(plan.selection_tags) > 0
  }

  name         = "${each.value.name}-selection"
  iam_role_arn = coalesce(var.backup_role_arn, "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/AWSBackupDefaultServiceRole")
  plan_id      = aws_backup_plan.this[each.key].id

  dynamic "selection_tag" {
    for_each = each.value.selection_tags
    content {
      type  = "STRINGEQUALS"
      key   = selection_tag.key
      value = selection_tag.value
    }
  }
}
