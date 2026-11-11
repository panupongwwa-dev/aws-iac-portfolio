resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = var.github_thumbprints

  tags = merge({ ManagedBy = "terraform" }, var.tags)
}

data "aws_iam_openid_connect_provider" "github" {
  count = var.create_oidc_provider ? 0 : 1
  url   = "https://token.actions.githubusercontent.com"
}

locals {
  oidc_provider_arn = var.create_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : data.aws_iam_openid_connect_provider.github[0].arn

  # flatten (role, managed_policy_arn) pairs for attachment
  role_managed_policies = {
    for pair in flatten([
      for k, v in var.roles : [
        for arn in v.managed_policy_arns : { key = "${k}::${arn}", role = k, arn = arn }
      ]
    ]) : pair.key => pair
  }
}

resource "aws_iam_role" "this" {
  for_each = var.roles

  name                 = each.key
  max_session_duration = each.value.max_session_duration

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = local.oidc_provider_arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        # Two spellings per subject, because GitHub is midway through
        # changing this claim. Older repos still emit the classic
        #   repo:<org>/<repo>:<subject>
        # while newer ones emit numeric owner and repo IDs inline:
        #   repo:<org>@<owner-id>/<repo>@<repo-id>:<subject>
        # The IDs are the point — they survive a rename, where the classic
        # form silently starts matching whoever takes the old name.
        #
        # Which form a repo uses is GitHub's call, not a setting here: two
        # repos under the same owner can report different forms with
        # identical customization settings (use_default=true,
        # use_immutable_subject=false). When that happens, a role that only
        # trusts the classic form fails with "Not authorized to perform
        # sts:AssumeRoleWithWebIdentity", with nothing to say the subject
        # simply did not match.
        #
        # The @* wildcards are narrow: they pin this exact org and repo name
        # and only leave the numeric IDs open.
        StringLike = {
          "token.actions.githubusercontent.com:sub" = flatten([
            for s in each.value.subjects : [
              "repo:${each.value.github_org}/${each.value.github_repo}:${s}",
              "repo:${each.value.github_org}@*/${each.value.github_repo}@*:${s}",
            ]
          ])
        }
      }
    }]
  })

  tags = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each = local.role_managed_policies

  role       = aws_iam_role.this[each.value.role].name
  policy_arn = each.value.arn
}

resource "aws_iam_role_policy" "inline" {
  for_each = { for k, v in var.roles : k => v if v.inline_policy_json != null }

  name   = "${each.key}-inline"
  role   = aws_iam_role.this[each.key].id
  policy = each.value.inline_policy_json
}
