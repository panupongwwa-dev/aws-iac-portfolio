locals {
  exclusion = length(var.excluded_role_arns) > 0 ? {
    Condition = {
      StringNotLike = { "aws:PrincipalARN" = var.excluded_role_arns }
    }
  } : {}

  statements = [
    merge({
      Sid      = "DenyRDSInstanceDeletion"
      Effect   = "Deny"
      Action   = ["rds:DeleteDBInstance", "rds:DeleteDBInstanceAutomatedBackup"]
      Resource = ["*"]
    }, local.exclusion),
    merge({
      Sid      = "DenyAuroraClusterDeletion"
      Effect   = "Deny"
      Action   = ["rds:DeleteDBCluster", "rds:DeleteDBClusterAutomatedBackup"]
      Resource = ["*"]
    }, local.exclusion),
    merge({
      Sid      = "DenyRDSSnapshotDeletion"
      Effect   = "Deny"
      Action   = ["rds:DeleteDBSnapshot", "rds:DeleteDBClusterSnapshot"]
      Resource = ["*"]
    }, local.exclusion),
  ]
}

resource "aws_organizations_policy" "this" {
  name        = var.name
  description = var.description
  type        = "SERVICE_CONTROL_POLICY"
  tags        = merge({ ManagedBy = "terraform" }, var.tags)

  content = jsonencode({
    Version   = "2012-10-17"
    Statement = local.statements
  })
}

resource "aws_organizations_policy_attachment" "this" {
  for_each  = toset(var.target_ids)
  policy_id = aws_organizations_policy.this.id
  target_id = each.value
}
