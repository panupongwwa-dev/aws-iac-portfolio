# =============================================================================
# examples/org-guardrails — preventive guardrails (SCPs) attached per OU.
#
# One table (local.ou_scps) decides which guardrail is attached to which OU.
# The SCP modules are generic; this file only wires them together.
# Every ID in this example is a placeholder.
# =============================================================================

locals {
  # Guardrails this stack knows how to attach.
  available_scps = [
    "deny_root_user", "require_tags", "deny_expensive_ec2", "deny_rds_deletion",
    "deny_s3_deletion", "restrict_iam_admin", "global_security_baseline",
  ]

  # OU => guardrails. Add a name to attach it, remove it to detach it.
  # global_security_baseline merges protect-security-services,
  # protect-log-archive and deny-leaving-org into ONE policy, which saves two
  # slots per OU against the AWS limit on SCPs attached to a single target.
  ou_scps = {
    development = ["deny_root_user", "require_tags", "deny_expensive_ec2", "restrict_iam_admin", "global_security_baseline"]
    production  = ["deny_root_user", "require_tags", "deny_expensive_ec2", "deny_rds_deletion", "deny_s3_deletion", "restrict_iam_admin", "global_security_baseline"]
    security    = ["deny_root_user", "restrict_iam_admin", "global_security_baseline"]
  }

  # Roles that only AWS automation can assume (Control Tower and
  # service-managed StackSets). No human can reach them, so exempting them
  # keeps baselines re-appliable without opening a door for people.
  automation_role_arns = [
    "arn:aws:iam::*:role/AWSControlTowerExecution",
    "arn:aws:iam::*:role/stacksets-exec-*",
    "arn:aws:iam::*:role/aws-controltower-*",
  ]
}

# Flip the table (OU => SCPs) into (SCP => OU IDs) for the modules below.
locals {
  scp_targets = {
    for scp in local.available_scps :
    scp => [for ou_name, scps in local.ou_scps : var.ous[ou_name] if contains(scps, scp)]
  }
}

# Catch a misspelled guardrail name at plan time instead of silently skipping it.
check "scp_names_valid" {
  assert {
    condition = alltrue([
      for ou, scps in local.ou_scps : alltrue([for s in scps : contains(local.available_scps, s)])
    ])
    error_message = "ou_scps contains an unknown SCP name; it must be one of available_scps."
  }
}

module "scp_deny_root" {
  source     = "../../organization/scp/deny-root-user"
  count      = length(local.scp_targets["deny_root_user"]) > 0 ? 1 : 0
  target_ids = local.scp_targets["deny_root_user"]
  tags       = var.tags
}

module "scp_require_tags" {
  source             = "../../organization/scp/require-tags"
  count              = length(local.scp_targets["require_tags"]) > 0 ? 1 : 0
  required_tag_keys  = ["Environment", "Owner", "CostCenter"]
  target_ids         = local.scp_targets["require_tags"]
  excluded_role_arns = local.automation_role_arns
  tags               = var.tags
}

module "scp_deny_rds_deletion" {
  source     = "../../organization/scp/deny-rds-deletion"
  count      = length(local.scp_targets["deny_rds_deletion"]) > 0 ? 1 : 0
  target_ids = local.scp_targets["deny_rds_deletion"]
  tags       = var.tags
}

module "scp_restrict_iam_admin" {
  source     = "../../organization/scp/restrict-iam-admin"
  count      = length(local.scp_targets["restrict_iam_admin"]) > 0 ? 1 : 0
  target_ids = local.scp_targets["restrict_iam_admin"]

  # Accounts use IAM Identity Center only, so IAM users are denied outright.
  deny_iam_user_creation = true
  excluded_role_arns = [
    "arn:aws:iam::*:role/stacksets-exec-*",
    "arn:aws:iam::*:role/AWSControlTowerExecution",
  ]
  tags = var.tags
}

module "scp_global_security_baseline" {
  source     = "../../organization/scp/global-security-baseline"
  count      = length(local.scp_targets["global_security_baseline"]) > 0 ? 1 : 0
  target_ids = local.scp_targets["global_security_baseline"]

  log_archive_bucket_prefixes = ["aws-controltower-logs", "org-audit-logs"]
  excluded_role_arns          = local.automation_role_arns
  tags                        = var.tags
}

# Custom inline SCPs use the generic module with their own policy document.
module "scp_deny_s3_deletion" {
  source      = "../../organization/scp"
  count       = length(local.scp_targets["deny_s3_deletion"]) > 0 ? 1 : 0
  name        = "deny-s3-deletion"
  description = "Deny deletion of S3 buckets and their protective configuration"
  target_ids  = local.scp_targets["deny_s3_deletion"]

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DenyS3BucketDeletion"
      Effect   = "Deny"
      Action   = ["s3:DeleteBucket", "s3:DeleteBucketPolicy", "s3:DeleteBucketEncryption", "s3:DeleteBucketLifecycle", "s3:DeleteBucketReplication"]
      Resource = "*"
    }]
  })

  tags = var.tags
}

module "scp_deny_expensive_ec2" {
  source      = "../../organization/scp"
  count       = length(local.scp_targets["deny_expensive_ec2"]) > 0 ? 1 : 0
  name        = "deny-expensive-ec2"
  description = "Allow only small EC2 instance types"
  target_ids  = local.scp_targets["deny_expensive_ec2"]

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "DenyLargeInstances"
      Effect   = "Deny"
      Action   = "ec2:RunInstances"
      Resource = "arn:aws:ec2:*:*:instance/*"
      Condition = {
        StringNotLike = { "ec2:InstanceType" = ["t3.nano", "t3.micro", "t3.small"] }
      }
    }]
  })

  tags = var.tags
}
