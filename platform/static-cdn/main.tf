# =============================================================================
# platform/static-cdn — CloudFront in front of TWO origins:
#   /assets/*, /vendors/* (etc.) -> private S3 bucket (cached, via OAC)
#   everything else            -> existing API Gateway / Lambda origin (uncached)
#
# This exists because every static CSS/JS/font/icon request was previously
# proxied through Lambda too — a page with ~25 asset tags meant ~25 concurrent
# Lambda invocations per page load, which overwhelms low Provisioned
# Concurrency (esp. right after a deploy, when nothing is warm) and shows up
# as a half-unstyled page. Moving statics to S3+CloudFront removes them from
# Lambda's concurrency budget entirely. No PHP template changes needed: paths
# are already relative ("assets/css/x.css"), and CloudFront's origin_path on
# the API Gateway origin transparently prepends the stage name, so the
# CloudFront-facing URL has no stage prefix to begin with.
# =============================================================================

resource "aws_s3_bucket" "static" {
  bucket = "${var.name}-static"
  tags   = merge({ ManagedBy = "terraform" }, var.tags)
}

resource "aws_s3_bucket_public_access_block" "static" {
  bucket = aws_s3_bucket.static.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "static" {
  bucket = aws_s3_bucket.static.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_cloudfront_origin_access_control" "static" {
  name                              = "${var.name}-static"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_s3_bucket_policy" "static" {
  bucket = aws_s3_bucket.static.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid       = "AllowCloudFrontOAC"
      Effect    = "Allow"
      Principal = { Service = "cloudfront.amazonaws.com" }
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.static.arn}/*"
      Condition = {
        StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.this.arn }
      }
    }]
  })
}

resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  price_class     = var.price_class
  comment         = var.name
  is_ipv6_enabled = true
  aliases         = var.aliases

  origin {
    domain_name              = aws_s3_bucket.static.bucket_regional_domain_name
    origin_id                = "s3-static"
    origin_access_control_id = aws_cloudfront_origin_access_control.static.id
  }

  origin {
    domain_name = var.api_gateway_domain_name
    origin_id   = "api-gateway"
    origin_path = var.api_gateway_origin_path

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # Default: everything dynamic (PHP pages, API calls) -> Lambda via API Gateway, uncached.
  default_cache_behavior {
    target_origin_id       = "api-gateway"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS", "PUT", "POST", "PATCH", "DELETE"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = true
      # NOT "*" — that forwards the viewer's Host header (the CloudFront domain)
      # straight through to API Gateway, which validates Host against its own
      # execute-api domain and rejects anything else with 403 Forbidden.
      # Omitting Host here makes CloudFront use the origin's real domain instead.
      headers = ["Accept", "Accept-Language", "Authorization", "Referer", "User-Agent", "X-Forwarded-For"]
      cookies {
        forward = "all"
      }
    }

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  dynamic "ordered_cache_behavior" {
    for_each = var.static_path_patterns
    content {
      path_pattern           = ordered_cache_behavior.value
      target_origin_id       = "s3-static"
      viewer_protocol_policy = "redirect-to-https"
      allowed_methods        = ["GET", "HEAD", "OPTIONS"]
      cached_methods         = ["GET", "HEAD"]
      compress               = true

      forwarded_values {
        query_string = false
        cookies {
          forward = "none"
        }
      }

      min_ttl     = var.static_cache_min_ttl
      default_ttl = var.static_cache_default_ttl
      max_ttl     = var.static_cache_max_ttl
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.acm_certificate_arn == ""
    acm_certificate_arn            = var.acm_certificate_arn == "" ? null : var.acm_certificate_arn
    ssl_support_method             = var.acm_certificate_arn == "" ? null : "sni-only"
    minimum_protocol_version       = var.acm_certificate_arn == "" ? null : "TLSv1.2_2021"
  }

  tags = merge({ ManagedBy = "terraform" }, var.tags)

  # The *.cloudfront.net domain is generated fresh on every create — a
  # destroy+recreate (e.g. from a careless -replace, or a change to an
  # argument Terraform can't update in place) silently hands out a brand
  # new URL. For prod this domain is handed to external customers, so an
  # accidental replace is not just an outage, it breaks every link they
  # already have. Any plan that would destroy this resource must fail
  # loudly instead of going through.
  lifecycle {
    prevent_destroy = true
  }
}
