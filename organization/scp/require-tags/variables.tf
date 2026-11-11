variable "name" {
  description = "Name of the SCP"
  type        = string
  default     = "require-tags"
}

variable "description" {
  description = "Description of the SCP"
  type        = string
  default     = "Denies creation of key resources unless required tags are present at request time"
}

variable "target_ids" {
  description = "List of account IDs, OU IDs, or Root IDs to attach this policy to"
  type        = list(string)
}

variable "required_tag_keys" {
  description = "Tag keys that must be present on resource creation requests. One Deny statement is generated per key."
  type        = list(string)
  # Example: ["Environment", "CostCenter", "Owner"]
}

variable "enforced_actions" {
  description = "AWS actions that require the tags. Defaults to common resource-creation actions."
  type        = list(string)
  default = [
    "ec2:RunInstances",
    "ec2:CreateVolume",
    "ec2:CreateSnapshot",
    "rds:CreateDBInstance",
    "rds:CreateDBCluster",
    # s3:CreateBucket deliberately excluded: the S3 CreateBucket API has no
    # request-time tagging parameter, so Terraform (and most other tools)
    # always create the bucket untagged first, then tag it in a separate
    # PutBucketTagging call. Enforcing this Null check on CreateBucket itself
    # blocks every Terraform-managed bucket unconditionally — confirmed by
    # hitting this denying a workload's static-cdn bucket creation.
    "lambda:CreateFunction",
    "ecs:CreateCluster",
    "eks:CreateCluster",
    "elasticloadbalancing:CreateLoadBalancer",
    "sqs:CreateQueue",
    "sns:CreateTopic",
    "dynamodb:CreateTable"
  ]
}

variable "excluded_role_arns" {
  description = "IAM role ARN patterns exempt from this SCP (e.g. automation pipelines). Supports wildcards."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags applied to the policy"
  type        = map(string)
  default     = {}
}
