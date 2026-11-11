locals {
  # repos that need a lifecycle policy
  repos_with_lifecycle = {
    for k, v in var.repositories : k => v
    if v.expire_untagged_after_days != null || v.max_image_count != null
  }

  # repos that need a repository (resource) policy for pull access
  repos_with_policy = {
    for k, v in var.repositories : k => v
    if length(v.allowed_pull_principals) > 0 || v.allowed_pull_org_id != null
  }
}

resource "aws_ecr_repository" "this" {
  for_each = var.repositories

  name                 = each.key
  image_tag_mutability = each.value.image_tag_mutability
  force_delete         = each.value.force_delete

  image_scanning_configuration {
    scan_on_push = each.value.scan_on_push
  }

  encryption_configuration {
    encryption_type = each.value.kms_key_arn != null ? "KMS" : "AES256"
    kms_key         = each.value.kms_key_arn
  }

  tags = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)
}

resource "aws_ecr_lifecycle_policy" "this" {
  for_each   = local.repos_with_lifecycle
  repository = aws_ecr_repository.this[each.key].name

  # Built with for-expressions (tuples) so jsonencode keeps countNumber as an
  # integer. A `cond ? [obj] : []` ternary would unify to map(string) and ECR
  # rejects a string countNumber.
  policy = jsonencode({
    rules = concat(
      [for n in(each.value.expire_untagged_after_days != null ? [each.value.expire_untagged_after_days] : []) : {
        rulePriority = 1
        description  = "Expire untagged images"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = n
        }
        action = { type = "expire" }
      }],
      [for n in(each.value.max_image_count != null ? [each.value.max_image_count] : []) : {
        rulePriority = 2
        description  = "Keep only the most recent images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = n
        }
        action = { type = "expire" }
      }]
    )
  })
}

resource "aws_ecr_repository_policy" "this" {
  for_each   = local.repos_with_policy
  repository = aws_ecr_repository.this[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      merge(
        {
          Sid       = "AllowPull"
          Effect    = "Allow"
          Principal = { AWS = length(each.value.allowed_pull_principals) > 0 ? each.value.allowed_pull_principals : ["*"] }
          Action = [
            "ecr:GetDownloadUrlForLayer",
            "ecr:BatchGetImage",
            "ecr:BatchCheckLayerAvailability",
          ]
        },
        each.value.allowed_pull_org_id != null ? {
          Condition = { StringEquals = { "aws:PrincipalOrgID" = each.value.allowed_pull_org_id } }
        } : {}
      )
    ]
  })
}
