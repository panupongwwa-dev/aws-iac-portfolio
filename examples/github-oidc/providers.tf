# Runs in the workload account the GitHub Actions workflows deploy into.
# Credentials come from the environment, never from code or variables.
provider "aws" {
  region = var.region
}
