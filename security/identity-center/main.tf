data "aws_ssoadmin_instances" "this" {}

locals {
  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]
}

resource "aws_ssoadmin_permission_set" "this" {
  for_each = var.permission_sets

  name             = each.key
  description      = each.value.description
  instance_arn     = local.sso_instance_arn
  session_duration = each.value.session_duration

  tags = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)
}

resource "aws_ssoadmin_permission_set_inline_policy" "this" {
  for_each = { for k, v in var.permission_sets : k => v if v.inline_policy != null }

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.key].arn
  inline_policy      = each.value.inline_policy
}

resource "aws_ssoadmin_managed_policy_attachment" "this" {
  for_each = {
    for pair in flatten([
      for ps_key, ps_val in var.permission_sets : [
        for policy_arn in ps_val.managed_policy_arns : {
          key                = "${ps_key}||${policy_arn}"
          ps_key             = ps_key
          managed_policy_arn = policy_arn
        }
      ]
    ]) : pair.key => pair
  }

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.ps_key].arn
  managed_policy_arn = each.value.managed_policy_arn
}

resource "aws_ssoadmin_account_assignment" "this" {
  for_each = var.account_assignments

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.permission_set_key].arn
  principal_id       = each.value.principal_id
  principal_type     = each.value.principal_type
  target_id          = each.value.account_id
  target_type        = "AWS_ACCOUNT"
}
