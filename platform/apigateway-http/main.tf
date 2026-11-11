locals {
  # flatten (api, route) pairs → one map keyed by "api::route_key"
  routes = {
    for pair in flatten([
      for api_key, api in var.apis : [
        for rk, r in api.routes : {
          key                    = "${api_key}::${rk}"
          api_key                = api_key
          route_key              = rk
          lambda_invoke_arn      = r.lambda_invoke_arn
          lambda_function_name   = r.lambda_function_name
          payload_format_version = r.payload_format_version
          authorization_type     = r.authorization_type
        }
      ]
    ]) : pair.key => pair
  }
}

resource "aws_apigatewayv2_api" "this" {
  for_each = var.apis

  name          = each.key
  description   = each.value.description
  protocol_type = "HTTP"

  dynamic "cors_configuration" {
    for_each = each.value.cors != null ? [each.value.cors] : []
    content {
      allow_origins = cors_configuration.value.allow_origins
      allow_methods = cors_configuration.value.allow_methods
      allow_headers = cors_configuration.value.allow_headers
      max_age       = cors_configuration.value.max_age
    }
  }

  tags = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)
}

resource "aws_apigatewayv2_integration" "this" {
  for_each = local.routes

  api_id                 = aws_apigatewayv2_api.this[each.value.api_key].id
  integration_type       = "AWS_PROXY"
  integration_uri        = each.value.lambda_invoke_arn
  integration_method     = "POST"
  payload_format_version = each.value.payload_format_version
}

resource "aws_apigatewayv2_route" "this" {
  for_each = local.routes

  api_id             = aws_apigatewayv2_api.this[each.value.api_key].id
  route_key          = each.value.route_key
  target             = "integrations/${aws_apigatewayv2_integration.this[each.key].id}"
  authorization_type = each.value.authorization_type
}

resource "aws_apigatewayv2_stage" "this" {
  for_each = var.apis

  api_id      = aws_apigatewayv2_api.this[each.key].id
  name        = each.value.stage_name
  auto_deploy = each.value.auto_deploy

  dynamic "default_route_settings" {
    for_each = (each.value.throttling_burst_limit != null || each.value.throttling_rate_limit != null) ? [1] : []
    content {
      throttling_burst_limit = each.value.throttling_burst_limit
      throttling_rate_limit  = each.value.throttling_rate_limit
    }
  }

  dynamic "access_log_settings" {
    for_each = each.value.access_log_destination_arn != null ? [1] : []
    content {
      destination_arn = each.value.access_log_destination_arn
      format = jsonencode({
        requestId      = "$context.requestId"
        ip             = "$context.identity.sourceIp"
        requestTime    = "$context.requestTime"
        httpMethod     = "$context.httpMethod"
        routeKey       = "$context.routeKey"
        status         = "$context.status"
        protocol       = "$context.protocol"
        responseLength = "$context.responseLength"
      })
    }
  }

  tags = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)
}

# Allow API Gateway to invoke each integrated Lambda
resource "aws_lambda_permission" "this" {
  for_each = local.routes

  statement_id  = "AllowAPIGW-${replace(each.key, "/[^a-zA-Z0-9]+/", "-")}"
  action        = "lambda:InvokeFunction"
  function_name = each.value.lambda_function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this[each.value.api_key].execution_arn}/*/*"
}
