# Runs in the AWS Organizations management account. Credentials come from the
# environment (an SSO profile locally, a GitHub OIDC role in CI) — never from
# code or variables.
provider "aws" {
  region = var.region

  default_tags {
    tags = var.tags
  }
}
