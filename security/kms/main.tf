data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

data "aws_iam_policy_document" "key_default" {
  for_each = { for k, v in var.keys : k => v if v.policy == null }

  statement {
    sid       = "EnableRootAccess"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }

  dynamic "statement" {
    for_each = length(each.value.admin_arns) > 0 ? [1] : []
    content {
      sid    = "KeyAdministration"
      effect = "Allow"
      actions = [
        "kms:Create*", "kms:Describe*", "kms:Enable*", "kms:List*",
        "kms:Put*", "kms:Update*", "kms:Revoke*", "kms:Disable*",
        "kms:Get*", "kms:Delete*", "kms:TagResource", "kms:UntagResource",
        "kms:ScheduleKeyDeletion", "kms:CancelKeyDeletion"
      ]
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = each.value.admin_arns
      }
    }
  }

  dynamic "statement" {
    for_each = length(each.value.user_arns) > 0 ? [1] : []
    content {
      sid    = "KeyUsage"
      effect = "Allow"
      actions = [
        "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
        "kms:GenerateDataKey*", "kms:DescribeKey"
      ]
      resources = ["*"]
      principals {
        type        = "AWS"
        identifiers = each.value.user_arns
      }
    }
  }

  dynamic "statement" {
    for_each = length(each.value.service_principals) > 0 ? [1] : []
    content {
      sid    = "ServiceAccess"
      effect = "Allow"
      actions = [
        "kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*",
        "kms:GenerateDataKey*", "kms:DescribeKey", "kms:CreateGrant"
      ]
      resources = ["*"]
      principals {
        type        = "Service"
        identifiers = each.value.service_principals
      }
    }
  }
}

resource "aws_kms_key" "this" {
  for_each = var.keys

  description              = each.value.description
  key_usage                = each.value.key_usage
  customer_master_key_spec = each.value.key_spec
  enable_key_rotation      = each.value.enable_rotation
  rotation_period_in_days  = each.value.enable_rotation ? each.value.rotation_period_in_days : null
  deletion_window_in_days  = each.value.deletion_window_in_days
  is_enabled               = true

  policy = each.value.policy != null ? each.value.policy : data.aws_iam_policy_document.key_default[each.key].json

  tags = merge({ Name = each.key, ManagedBy = "terraform" }, var.tags, each.value.tags)
}

resource "aws_kms_alias" "this" {
  for_each      = { for k, v in var.keys : k => v if v.alias != null }
  name          = "alias/${each.value.alias}"
  target_key_id = aws_kms_key.this[each.key].key_id
}
