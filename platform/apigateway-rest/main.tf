resource "aws_api_gateway_rest_api" "this" {
  for_each = var.apis

  name        = each.key
  description = each.value.description

  endpoint_configuration {
    types = [each.value.endpoint_type]
  }

  tags = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)
}

# Greedy proxy resource: /{proxy+}
resource "aws_api_gateway_resource" "proxy" {
  for_each = var.apis

  rest_api_id = aws_api_gateway_rest_api.this[each.key].id
  parent_id   = aws_api_gateway_rest_api.this[each.key].root_resource_id
  path_part   = "{proxy+}"
}

# ANY /{proxy+} → Lambda proxy
resource "aws_api_gateway_method" "proxy" {
  for_each = var.apis

  rest_api_id      = aws_api_gateway_rest_api.this[each.key].id
  resource_id      = aws_api_gateway_resource.proxy[each.key].id
  http_method      = "ANY"
  authorization    = "NONE"
  api_key_required = each.value.api_key_required
}

resource "aws_api_gateway_integration" "proxy" {
  for_each = var.apis

  rest_api_id             = aws_api_gateway_rest_api.this[each.key].id
  resource_id             = aws_api_gateway_resource.proxy[each.key].id
  http_method             = aws_api_gateway_method.proxy[each.key].http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = each.value.lambda_invoke_arn
}

# ANY / (root) → Lambda proxy
resource "aws_api_gateway_method" "root" {
  for_each = var.apis

  rest_api_id      = aws_api_gateway_rest_api.this[each.key].id
  resource_id      = aws_api_gateway_rest_api.this[each.key].root_resource_id
  http_method      = "ANY"
  authorization    = "NONE"
  api_key_required = each.value.api_key_required
}

resource "aws_api_gateway_integration" "root" {
  for_each = var.apis

  rest_api_id             = aws_api_gateway_rest_api.this[each.key].id
  resource_id             = aws_api_gateway_rest_api.this[each.key].root_resource_id
  http_method             = aws_api_gateway_method.root[each.key].http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = each.value.lambda_invoke_arn
}

resource "aws_api_gateway_deployment" "this" {
  for_each = var.apis

  rest_api_id = aws_api_gateway_rest_api.this[each.key].id

  # redeploy when the API surface changes
  triggers = {
    redeploy = sha1(jsonencode([
      aws_api_gateway_resource.proxy[each.key].id,
      aws_api_gateway_method.proxy[each.key].id,
      aws_api_gateway_integration.proxy[each.key].id,
      aws_api_gateway_method.root[each.key].id,
      aws_api_gateway_integration.root[each.key].id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.proxy,
    aws_api_gateway_integration.root,
  ]
}

resource "aws_api_gateway_stage" "this" {
  for_each = var.apis

  rest_api_id   = aws_api_gateway_rest_api.this[each.key].id
  deployment_id = aws_api_gateway_deployment.this[each.key].id
  stage_name    = each.value.stage_name

  dynamic "access_log_settings" {
    for_each = each.value.access_log_destination_arn != null ? [1] : []
    content {
      destination_arn = each.value.access_log_destination_arn
      format = jsonencode({
        requestId    = "$context.requestId"
        ip           = "$context.identity.sourceIp"
        requestTime  = "$context.requestTime"
        httpMethod   = "$context.httpMethod"
        resourcePath = "$context.resourcePath"
        status       = "$context.status"
        protocol     = "$context.protocol"
        responseLen  = "$context.responseLength"
      })
    }
  }

  tags = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)
}

# Throttling via method settings (applies to all methods/*)
resource "aws_api_gateway_method_settings" "this" {
  for_each = { for k, v in var.apis : k => v if v.throttling_burst_limit != null || v.throttling_rate_limit != null }

  rest_api_id = aws_api_gateway_rest_api.this[each.key].id
  stage_name  = aws_api_gateway_stage.this[each.key].stage_name
  method_path = "*/*"

  settings {
    throttling_burst_limit = each.value.throttling_burst_limit
    throttling_rate_limit  = each.value.throttling_rate_limit
  }
}

# Allow API Gateway to invoke the backing Lambda
resource "aws_lambda_permission" "this" {
  for_each = var.apis

  statement_id  = "AllowAPIGW-${replace(each.key, "/[^a-zA-Z0-9]+/", "-")}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.this[each.key].execution_arn}/*/*"
}
