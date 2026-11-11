locals {
  exclusion = length(var.excluded_role_arns) > 0 ? {
    Condition = {
      StringNotLike = {
        "aws:PrincipalARN" = var.excluded_role_arns
      }
    }
  } : {}

  # Generate one Deny statement per required tag key so that missing ANY tag triggers a deny
  tag_statements = [
    for tag_key in var.required_tag_keys : merge({
      Sid      = "DenyWithoutTag${replace(replace(tag_key, "-", ""), "_", "")}"
      Effect   = "Deny"
      Action   = var.enforced_actions
      Resource = ["*"]
      Condition = merge(
        { Null = { "aws:RequestTag/${tag_key}" = "true" } },
        length(var.excluded_role_arns) > 0 ? {
          StringNotLike = { "aws:PrincipalARN" = var.excluded_role_arns }
        } : {}
      )
    }, {})
  ]
}

resource "aws_organizations_policy" "this" {
  name        = var.name
  description = var.description
  type        = "SERVICE_CONTROL_POLICY"
  tags        = merge({ ManagedBy = "terraform" }, var.tags)

  content = jsonencode({
    Version   = "2012-10-17"
    Statement = local.tag_statements
  })
}

resource "aws_organizations_policy_attachment" "this" {
  for_each  = toset(var.target_ids)
  policy_id = aws_organizations_policy.this.id
  target_id = each.value
}
