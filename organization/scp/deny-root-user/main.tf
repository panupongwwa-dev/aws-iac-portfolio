data "aws_partition" "current" {}

resource "aws_organizations_policy" "this" {
  name        = var.name
  description = var.description
  type        = "SERVICE_CONTROL_POLICY"
  tags        = merge({ ManagedBy = "terraform" }, var.tags)

  content = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "DenyRootUser"
        Effect   = "Deny"
        Action   = ["*"]
        Resource = ["*"]
        Condition = {
          StringLike = {
            "aws:PrincipalArn" = ["arn:${data.aws_partition.current.partition}:iam::*:root"]
          }
        }
      }
    ]
  })
}

resource "aws_organizations_policy_attachment" "this" {
  for_each  = toset(var.target_ids)
  policy_id = aws_organizations_policy.this.id
  target_id = each.value
}
