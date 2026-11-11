data "aws_partition" "current" {}

locals {
  # functions that need VPC access (extra managed policy)
  vpc_functions = { for k, v in var.functions : k => v if v.vpc_config != null }

  # flatten (function, managed_policy_arn) pairs for attachment
  fn_managed_policies = {
    for pair in flatten([
      for k, v in var.functions : [
        for arn in v.managed_policy_arns : { key = "${k}::${arn}", fn = k, arn = arn }
      ]
    ]) : pair.key => pair
  }
}

# ---- IAM execution role (one per function) --------------------------------
resource "aws_iam_role" "this" {
  for_each = var.functions
  name     = "${each.key}-lambda"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)
}

resource "aws_iam_role_policy_attachment" "basic" {
  for_each   = var.functions
  role       = aws_iam_role.this[each.key].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "vpc" {
  for_each   = local.vpc_functions
  role       = aws_iam_role.this[each.key].name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = local.fn_managed_policies
  role       = aws_iam_role.this[each.value.fn].name
  policy_arn = each.value.arn
}

resource "aws_iam_role_policy" "inline" {
  for_each = { for k, v in var.functions : k => v if v.inline_policy_json != null }
  name     = "${each.key}-inline"
  role     = aws_iam_role.this[each.key].id
  policy   = each.value.inline_policy_json
}

# ---- Log group (managed, so retention/KMS are controlled) ------------------
resource "aws_cloudwatch_log_group" "this" {
  for_each          = var.functions
  name              = "/aws/lambda/${each.key}"
  retention_in_days = each.value.log_retention_days
  kms_key_id        = each.value.kms_key_arn
  tags              = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)
}

# ---- Lambda function ------------------------------------------------------
resource "aws_lambda_function" "this" {
  for_each = var.functions

  function_name = each.key
  description   = each.value.description
  role          = aws_iam_role.this[each.key].arn
  architectures = each.value.architectures

  package_type = each.value.image_uri != null ? "Image" : "Zip"
  image_uri    = each.value.image_uri

  # zip-only attributes (null when using a container image)
  runtime          = each.value.image_uri == null ? each.value.runtime : null
  handler          = each.value.image_uri == null ? each.value.handler : null
  filename         = each.value.filename
  source_code_hash = each.value.source_code_hash
  s3_bucket        = each.value.s3_bucket
  s3_key           = each.value.s3_key

  memory_size                    = each.value.memory_size
  timeout                        = each.value.timeout
  layers                         = each.value.layers
  kms_key_arn                    = each.value.kms_key_arn
  reserved_concurrent_executions = each.value.reserved_concurrent_executions
  publish                        = each.value.publish

  ephemeral_storage {
    size = each.value.ephemeral_storage_mb
  }

  dynamic "environment" {
    for_each = length(each.value.environment_variables) > 0 ? [1] : []
    content {
      variables = each.value.environment_variables
    }
  }

  dynamic "vpc_config" {
    for_each = each.value.vpc_config != null ? [each.value.vpc_config] : []
    content {
      subnet_ids         = vpc_config.value.subnet_ids
      security_group_ids = vpc_config.value.security_group_ids
    }
  }

  dynamic "tracing_config" {
    for_each = each.value.tracing_mode != null ? [each.value.tracing_mode] : []
    content {
      mode = tracing_config.value
    }
  }

  tags = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)

  lifecycle {
    # Function code is deployed out-of-band by each application's own CI
    # (aws lambda update-function-code) — a container image for one workload,
    # an S3 zip for another — so Terraform must never revert it
    # or redeploy it. These attributes only matter when a function is first
    # created; after that, this module manages configuration only.
    ignore_changes = [image_uri, filename, source_code_hash, s3_bucket, s3_key, s3_object_version]
  }

  depends_on = [aws_cloudwatch_log_group.this]
}

# One alias per published function, tracking whatever version was just
# published — Terraform re-points it automatically on every code change
# since aws_lambda_function.this[*].version updates as part of the same
# apply. Provisioned Concurrency (configured outside this module, e.g. via
# Application Auto Scaling) targets "function:<name>:live".
resource "aws_lambda_alias" "live" {
  for_each = { for k, v in var.functions : k => v if v.publish }

  name             = "live"
  function_name    = aws_lambda_function.this[each.key].function_name
  function_version = aws_lambda_function.this[each.key].version
}
