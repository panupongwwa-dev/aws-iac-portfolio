# Runs in the dedicated security-tooling account. The management account has
# already registered it as delegated administrator for GuardDuty, Security Hub
# and Inspector. Credentials come from the environment, never from code.
provider "aws" {
  region = var.region

  default_tags {
    tags = var.tags
  }
}
