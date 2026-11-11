variable "repositories" {
  description = "Map of ECR repositories to create. Key = repository name."
  type = map(object({
    image_tag_mutability = optional(string, "IMMUTABLE") # IMMUTABLE | MUTABLE
    scan_on_push         = optional(bool, true)
    force_delete         = optional(bool, false)
    kms_key_arn          = optional(string) # null => AES256 (AWS-managed)

    # ---- lifecycle policy (optional) ----
    expire_untagged_after_days = optional(number) # null disables this rule
    max_image_count            = optional(number) # keep only the most recent N images; null disables

    # ---- repository policy: cross-account / org pull access (optional) ----
    allowed_pull_principals = optional(list(string), []) # account IDs or IAM ARNs
    allowed_pull_org_id     = optional(string)           # allow the whole org to pull (o-xxxx)

    tags = optional(map(string), {})
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.repositories : contains(["IMMUTABLE", "MUTABLE"], v.image_tag_mutability)
    ])
    error_message = "image_tag_mutability must be IMMUTABLE or MUTABLE."
  }
}

variable "tags" {
  description = "Tags applied to all repositories"
  type        = map(string)
  default     = {}
}
