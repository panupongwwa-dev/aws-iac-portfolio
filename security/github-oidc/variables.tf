variable "create_oidc_provider" {
  description = "Create the GitHub OIDC provider in this account. Set false if it already exists (only one allowed per account)."
  type        = bool
  default     = true
}

variable "github_thumbprints" {
  description = "Thumbprints for token.actions.githubusercontent.com. AWS no longer strictly validates these, but the resource requires a non-empty list."
  type        = list(string)
  default = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fce",
  ]
}

variable "roles" {
  description = "Map of IAM roles GitHub Actions can assume via OIDC. Key = role name."
  type = map(object({
    github_org  = string
    github_repo = string

    # Which workflow refs may assume the role. Examples:
    #   "ref:refs/heads/main", "ref:refs/tags/*", "environment:prod", "pull_request"
    subjects = optional(list(string), ["ref:refs/heads/main"])

    managed_policy_arns  = optional(list(string), [])
    inline_policy_json   = optional(string)
    max_session_duration = optional(number, 3600)

    tags = optional(map(string), {})
  }))
  default = {}
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
