resource "aws_secretsmanager_secret" "this" {
  for_each = var.secrets

  name        = each.value.name
  description = each.value.description
  kms_key_id  = each.value.kms_key_arn

  dynamic "replica" {
    for_each = each.value.replica_regions
    content {
      region     = replica.value.region
      kms_key_id = replica.value.kms_key_arn
    }
  }

  recovery_window_in_days = each.value.recovery_window_in_days
  tags                    = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)
}

resource "aws_secretsmanager_secret_rotation" "this" {
  for_each = { for k, v in var.secrets : k => v if v.rotation != null }

  secret_id           = aws_secretsmanager_secret.this[each.key].id
  rotation_lambda_arn = each.value.rotation.lambda_arn

  rotation_rules {
    automatically_after_days = each.value.rotation.automatically_after_days
    duration                 = each.value.rotation.duration
    schedule_expression      = each.value.rotation.schedule_expression
  }
}
