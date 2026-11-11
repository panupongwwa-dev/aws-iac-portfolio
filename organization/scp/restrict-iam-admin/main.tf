data "aws_partition" "current" {}

locals {
  exclusion = length(var.excluded_role_arns) > 0 ? {
    Condition = {
      StringNotLike = {
        "aws:PrincipalARN" = var.excluded_role_arns
      }
    }
  } : {}

  # Managed policy ARNs blocked from being attached
  blocked_policy_arns = distinct(concat(
    [
      "arn:${data.aws_partition.current.partition}:iam::aws:policy/AdministratorAccess",
      "arn:${data.aws_partition.current.partition}:iam::aws:policy/IAMFullAccess"
    ],
    var.additional_blocked_policy_arns
  ))

  # Statements for deny-create-iam-user (only added when enabled)
  deny_iam_user_statements = var.deny_iam_user_creation ? [
    merge({
      Sid    = "DenyCreateIAMUser"
      Effect = "Deny"
      Action = [
        "iam:CreateUser",
        "iam:CreateLoginProfile",
        "iam:CreateAccessKey"
      ]
      Resource = ["*"]
    }, local.exclusion)
  ] : []
}

resource "aws_organizations_policy" "this" {
  name        = var.name
  description = var.description
  type        = "SERVICE_CONTROL_POLICY"
  tags        = merge({ ManagedBy = "terraform" }, var.tags)

  content = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        merge({
          Sid    = "DenyAttachAdminManagedPolicies"
          Effect = "Deny"
          Action = [
            "iam:AttachRolePolicy",
            "iam:AttachUserPolicy",
            "iam:AttachGroupPolicy",
            "iam:PutRolePolicy",
            "iam:PutUserPolicy",
            "iam:PutGroupPolicy"
          ]
          Resource = ["*"]
          Condition = merge(
            length(var.excluded_role_arns) > 0 ? {
              StringNotLike = {
                "aws:PrincipalARN" = var.excluded_role_arns
              }
            } : {},
            {
              ArnLike = {
                "iam:PolicyARN" = local.blocked_policy_arns
              }
            }
          )
        }, {}),

        merge({
          Sid    = "DenyCreateRootAccessKeys"
          Effect = "Deny"
          Action = [
            "iam:CreateAccessKey",
            "iam:CreateVirtualMFADevice",
            "iam:DeactivateMFADevice",
            "iam:DeleteVirtualMFADevice"
          ]
          Resource = ["arn:${data.aws_partition.current.partition}:iam::*:root"]
        }, local.exclusion),

        merge({
          Sid    = "DenyModifyAccountPasswordPolicy"
          Effect = "Deny"
          Action = [
            "iam:DeleteAccountPasswordPolicy",
            "iam:UpdateAccountPasswordPolicy"
          ]
          Resource = ["*"]
        }, local.exclusion)
      ],
      local.deny_iam_user_statements
    )
  })
}

resource "aws_organizations_policy_attachment" "this" {
  for_each  = toset(var.target_ids)
  policy_id = aws_organizations_policy.this.id
  target_id = each.value
}
