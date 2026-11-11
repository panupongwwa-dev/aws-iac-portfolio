# =============================================================================
# examples/github-oidc — keyless CI/CD: GitHub Actions assumes short-lived IAM
# roles through OIDC, so no AWS access key is ever stored in GitHub.
#
# Each role is pinned to one repository and to specific workflow triggers,
# and gets only the permissions its job needs.
# Every value in this example is a placeholder.
# =============================================================================

# Static-site deploy: sync files to one bucket and invalidate one distribution.
data "aws_iam_policy_document" "site_deploy" {
  statement {
    sid       = "ListSiteBucket"
    actions   = ["s3:ListBucket"]
    resources = ["arn:aws:s3:::${var.site_bucket_name}"]
  }

  statement {
    sid       = "WriteSiteObjects"
    actions   = ["s3:PutObject", "s3:DeleteObject"]
    resources = ["arn:aws:s3:::${var.site_bucket_name}/*"]
  }

  statement {
    sid       = "InvalidateSiteCache"
    actions   = ["cloudfront:CreateInvalidation"]
    resources = [var.site_distribution_arn]
  }
}

module "github_oidc" {
  source = "../../security/github-oidc"

  roles = {
    # Pull requests may only read: terraform plan, never apply.
    "github-actions-terraform-plan" = {
      github_org          = var.github_org
      github_repo         = var.infra_repo
      subjects            = ["pull_request"]
      managed_policy_arns = ["arn:aws:iam::aws:policy/ReadOnlyAccess"]
    }

    # Only pushes to main may deploy the site.
    "github-actions-site-deploy" = {
      github_org           = var.github_org
      github_repo          = var.site_repo
      subjects             = ["ref:refs/heads/main"]
      inline_policy_json   = data.aws_iam_policy_document.site_deploy.json
      max_session_duration = 3600
    }
  }
}

output "role_arns" {
  description = "Role ARNs to put in each workflow's aws-actions/configure-aws-credentials step"
  value       = module.github_oidc.role_arns
}
