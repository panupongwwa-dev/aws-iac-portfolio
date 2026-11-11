variable "name" {
  description = "Name of the SCP"
  type        = string
  default     = "deny-s3-public"
}

variable "description" {
  description = "Description of the SCP"
  type        = string
  default     = "Denies setting public ACLs on S3 buckets/objects and disabling S3 Public Access Block settings"
}

variable "target_ids" {
  description = "List of account IDs, OU IDs, or Root IDs to attach this policy to"
  type        = list(string)
}

variable "denied_acl_types" {
  description = "S3 canned ACLs that are denied. authenticated-read allows any AWS-authenticated user — treat as public."
  type        = list(string)
  default     = ["public-read", "public-read-write", "authenticated-read"]
}

variable "enforced_block_settings" {
  description = "Public Access Block settings that must not be disabled. One Deny statement is generated per setting."
  type        = list(string)
  default     = ["BlockPublicAcls", "IgnorePublicAcls", "BlockPublicPolicy", "RestrictPublicBuckets"]

  validation {
    condition = alltrue([
      for s in var.enforced_block_settings :
      contains(["BlockPublicAcls", "IgnorePublicAcls", "BlockPublicPolicy", "RestrictPublicBuckets"], s)
    ])
    error_message = "Valid values: BlockPublicAcls, IgnorePublicAcls, BlockPublicPolicy, RestrictPublicBuckets."
  }
}

variable "excluded_role_arns" {
  description = "IAM role ARN patterns exempt from this SCP (e.g. data-lake pipelines that need specific bucket policies). Supports wildcards."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to the policy"
  type        = map(string)
  default     = {}
}
