variable "region" {
  description = "Region of the workload account"
  type        = string
}

variable "github_org" {
  description = "GitHub organization or user that owns the repositories"
  type        = string
}

variable "infra_repo" {
  description = "Repository holding the Terraform code (read-only plan on pull requests)"
  type        = string
}

variable "site_repo" {
  description = "Repository holding the static site (deploys from main)"
  type        = string
}

variable "site_bucket_name" {
  description = "S3 bucket the static site is synced to"
  type        = string
}

variable "site_distribution_arn" {
  description = "CloudFront distribution in front of the site bucket"
  type        = string
}
