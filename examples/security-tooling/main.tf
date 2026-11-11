# =============================================================================
# examples/security-tooling — org-wide detective controls from one account.
#
#   GuardDuty     threat detection, auto-enabled for every member account
#   Security Hub  AWS Foundational Security Best Practices + CIS benchmark
#   Inspector     vulnerability scanning for EC2, ECR and Lambda
#   Export        Security Hub findings -> EventBridge -> Firehose -> S3 (SIEM feed)
#   Central logs  workload CloudWatch Logs -> Firehose -> S3 in this account
#
# Every ID in this example is a placeholder.
# =============================================================================

data "aws_region" "current" {}
data "aws_partition" "current" {}

locals {
  securityhub_standards = {
    fsbp = "arn:${data.aws_partition.current.partition}:securityhub:${data.aws_region.current.name}::standards/aws-foundational-security-best-practices/v/1.0.0"
    cis  = "arn:${data.aws_partition.current.partition}:securityhub:${data.aws_region.current.name}::standards/cis-aws-foundations-benchmark/v/1.4.0"
  }
}

module "guardduty" {
  source = "../../security/guardduty"

  is_delegated_admin      = true
  auto_enable_org_members = "ALL"
  datasources = {
    s3_logs            = true
    malware_protection = true
  }

  tags = var.tags
}

module "security_hub" {
  source = "../../security/security-hub"

  is_delegated_admin      = true
  auto_enable_org_members = true
  standards_arns          = local.securityhub_standards
}

module "inspector" {
  source = "../../security/inspector"

  is_delegated_admin = true
  resource_types     = ["EC2", "ECR", "LAMBDA"]

  # Lambda is not auto-enabled org-wide on purpose: the global-security-baseline
  # SCP denies inspector2:UpdateOrganizationConfiguration so nobody can switch
  # Inspector off for the whole organization. Workload accounts are enabled
  # explicitly instead, which uses a different, unblocked API.
  auto_enable = {
    ec2    = true
    ecr    = true
    lambda = false
  }
  member_account_ids = var.inspector_member_account_ids

  tags = var.tags
}

module "securityhub_export" {
  source = "../../security/securityhub-firehose-export"
  tags   = var.tags
}

module "logs_central" {
  source            = "../../security/cloudwatch-logs-central"
  source_log_groups = var.central_log_sources
  tags              = var.tags
}
