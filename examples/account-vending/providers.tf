# Runs in the AWS Organizations management account. Credentials come from the
# environment, never from code or variables.
provider "aws" {
  region = var.region
}
