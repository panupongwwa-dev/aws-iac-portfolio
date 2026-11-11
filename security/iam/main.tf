resource "aws_iam_role" "this" {
  for_each = var.roles

  name                 = each.key
  description          = each.value.description
  path                 = each.value.path
  max_session_duration = each.value.max_session_duration

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = each.value.trust_policy_statements
  })

  tags = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)
}

resource "aws_iam_instance_profile" "this" {
  for_each = { for k, v in var.roles : k => v if v.create_instance_profile }
  name     = each.key
  role     = aws_iam_role.this[each.key].name
  tags     = merge({ ManagedBy = "terraform" }, var.tags)
}

resource "aws_iam_policy" "this" {
  for_each = var.policies

  name        = each.key
  description = each.value.description
  path        = each.value.path
  policy      = each.value.policy_json
  tags        = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)
}

# Attach custom policies (defined in this module) to roles
resource "aws_iam_role_policy_attachment" "custom" {
  for_each = {
    for pair in flatten([
      for role_key, role_val in var.roles : [
        for policy_key in role_val.policy_keys : {
          key        = "${role_key}||${policy_key}"
          role_name  = role_key
          policy_arn = aws_iam_policy.this[policy_key].arn
        }
      ]
    ]) : pair.key => pair
  }

  role       = aws_iam_role.this[each.value.role_name].name
  policy_arn = each.value.policy_arn
}

# Attach AWS managed policies to roles
resource "aws_iam_role_policy_attachment" "managed" {
  for_each = {
    for pair in flatten([
      for role_key, role_val in var.roles : [
        for policy_arn in role_val.managed_policy_arns : {
          key        = "${role_key}||${policy_arn}"
          role_name  = role_key
          policy_arn = policy_arn
        }
      ]
    ]) : pair.key => pair
  }

  role       = aws_iam_role.this[each.value.role_name].name
  policy_arn = each.value.policy_arn
}
