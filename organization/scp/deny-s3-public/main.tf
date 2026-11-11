locals {
  # Inline exclusion condition — used in statements that already have a Condition block
  exclusion_condition = length(var.excluded_role_arns) > 0 ? {
    StringNotLike = { "aws:PrincipalARN" = var.excluded_role_arns }
  } : {}

  # Statement-level exclusion — used in statements that have no other Condition
  exclusion = length(var.excluded_role_arns) > 0 ? {
    Condition = {
      StringNotLike = { "aws:PrincipalARN" = var.excluded_role_arns }
    }
  } : {}

  # Deny setting public-read/public-read-write ACLs on buckets and objects
  acl_statement = merge({
    Sid      = "DenyS3PublicACL"
    Effect   = "Deny"
    Action   = ["s3:PutBucketAcl", "s3:PutObjectAcl"]
    Resource = ["*"]
    Condition = merge(
      { StringEquals = { "s3:x-amz-acl" = var.denied_acl_types } },
      local.exclusion_condition
    )
  }, {})

  # Deny removing the S3 public access block entirely
  remove_block_statement = merge({
    Sid      = "DenyRemovePublicAccessBlock"
    Effect   = "Deny"
    Action   = ["s3:DeletePublicAccessBlock"]
    Resource = ["*"]
  }, local.exclusion)

  # One statement per block setting — deny disabling each enforcement flag
  block_setting_statements = [
    for setting in var.enforced_block_settings : merge({
      Sid      = "DenyDisable${setting}"
      Effect   = "Deny"
      Action   = ["s3:PutBucketPublicAccessBlock"]
      Resource = ["*"]
      Condition = merge(
        { StringEquals = { "s3:PublicAccessBlockConfiguration/${setting}" = "false" } },
        local.exclusion_condition
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
    Version = "2012-10-17"
    Statement = concat(
      [local.acl_statement, local.remove_block_statement],
      local.block_setting_statements
    )
  })
}

resource "aws_organizations_policy_attachment" "this" {
  for_each  = toset(var.target_ids)
  policy_id = aws_organizations_policy.this.id
  target_id = each.value
}
