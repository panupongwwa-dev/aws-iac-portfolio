# =============================================================================
# security/splunk-poc — single-node Splunk on EC2 (spot optional via var.use_spot),
# for learning/testing Security Hub → Splunk ingestion. NOT for production:
# spot can be reclaimed with a 2-minute warning, and the root volume isn't
# preserved across interruption (re-apply to relaunch from scratch).
# =============================================================================

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default_public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  dynamic "filter" {
    for_each = var.availability_zone != null ? [var.availability_zone] : []
    content {
      name   = "availability-zone"
      values = [filter.value]
    }
  }
}

# Amazon Linux 2023 — yum-based, matches the user_data install script.
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "random_password" "splunk_admin" {
  length  = 20
  special = false # Splunk's user-seed.conf has issues with some shell-special characters
}

resource "aws_secretsmanager_secret" "splunk_admin" {
  name        = "${var.name}/splunk-admin-password"
  description = "Auto-generated Splunk admin password for ${var.name} (learning/POC instance)"
  tags        = merge({ ManagedBy = "terraform" }, var.tags)
}

resource "aws_secretsmanager_secret_version" "splunk_admin" {
  secret_id     = aws_secretsmanager_secret.splunk_admin.id
  secret_string = random_password.splunk_admin.result
}

resource "aws_security_group" "splunk" {
  name        = var.name
  description = "Splunk POC - web UI access only, no inbound SSH (use SSM Session Manager)"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Splunk Web UI"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = var.allowed_cidr_blocks
  }



  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge({ Name = var.name, ManagedBy = "terraform" }, var.tags)
}

resource "aws_iam_role" "splunk" {
  name = "${var.name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge({ ManagedBy = "terraform" }, var.tags)
}

# Read-only Security Hub access — used by the custom HEC poller script (user_data.sh.tpl)
# to call securityhub:GetFindings; no Splunkbase app/login needed.
resource "aws_iam_role_policy" "security_hub_read" {
  name = "security-hub-read"
  role = aws_iam_role.splunk.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "SecurityHubRead"
      Effect = "Allow"
      Action = [
        "securityhub:GetFindings",
        "securityhub:ListFindings",
        "securityhub:GetInsights",
        "securityhub:GetEnabledStandards",
        "securityhub:DescribeStandards",
        "securityhub:DescribeHub",
      ]
      Resource = "*"
    }]
  })
}

# Lets the instance fetch its own admin password (e.g. for unattended Splunk CLI auth).
resource "aws_iam_role_policy" "read_own_secret" {
  name = "read-own-secret"
  role = aws_iam_role.splunk.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadOwnSplunkAdminSecret"
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_secretsmanager_secret.splunk_admin.arn
    }]
  })
}

# Cross-account roles this instance may assume (e.g. a CloudTrail-reader role
# in the management account that trusts this instance's role).
resource "aws_iam_role_policy" "assume_cross_account_roles" {
  count = length(var.cross_account_assume_role_arns) > 0 ? 1 : 0
  name  = "assume-cross-account-roles"
  role  = aws_iam_role.splunk.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AssumeCrossAccountRoles"
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = var.cross_account_assume_role_arns
    }]
  })
}

# Read the Firehose-exported Security Hub findings bucket (same account, no
# role assumption needed — see the security/securityhub-firehose-export module).
resource "aws_iam_role_policy" "read_securityhub_export" {
  count = var.securityhub_export_bucket_name != "" ? 1 : 0
  name  = "read-securityhub-export"
  role  = aws_iam_role.splunk.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ReadSecurityHubExportBucket"
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        "arn:aws:s3:::${var.securityhub_export_bucket_name}",
        "arn:aws:s3:::${var.securityhub_export_bucket_name}/*",
      ]
    }]
  })
}

# Read the centralized cross-account CloudWatch Logs bucket (same account, no
# role assumption needed — see the security/cloudwatch-logs-central module).
resource "aws_iam_role_policy" "read_logs_central" {
  count = var.logs_central_bucket_name != "" ? 1 : 0
  name  = "read-logs-central"
  role  = aws_iam_role.splunk.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ReadLogsCentralBucket"
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        "arn:aws:s3:::${var.logs_central_bucket_name}",
        "arn:aws:s3:::${var.logs_central_bucket_name}/*",
      ]
    }]
  })
}

# Lets TA-aws's SQS-based S3 input pick up new objects in the logs_central
# bucket without polling S3 itself — see security/cloudwatch-logs-central.
resource "aws_iam_role_policy" "read_logs_central_sqs" {
  count = var.logs_central_sqs_queue_arn != "" ? 1 : 0
  name  = "read-logs-central-sqs"
  role  = aws_iam_role.splunk.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "ReadLogsCentralSqsQueue"
      Effect = "Allow"
      Action = [
        "sqs:ReceiveMessage",
        "sqs:DeleteMessage",
        "sqs:GetQueueAttributes",
      ]
      Resource = var.logs_central_sqs_queue_arn
    }]
  })
}

# Cross-account read for TA-aws's SQS-based S3 input (a workload prod account's
# VPC Flow Logs pilot). The bucket/queue policies on the prod side already name
# this role, but that resource-side grant alone isn't sufficient for SQS (and
# isn't reliable for S3 either) — this role's own identity policy must also
# explicitly allow the actions on those specific cross-account ARNs. Confirmed
# live: GetQueueAttributes failed with AccessDenied until this was added.
resource "aws_iam_role_policy" "read_vpc_flow_logs_native" {
  count = var.vpc_flow_logs_native_sqs_queue_arn != "" ? 1 : 0
  name  = "read-vpc-flow-logs-native"
  role  = aws_iam_role.splunk.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadVpcFlowLogsNativeBucket"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          "arn:aws:s3:::${var.vpc_flow_logs_native_bucket_name}",
          "arn:aws:s3:::${var.vpc_flow_logs_native_bucket_name}/*",
        ]
      },
      {
        Sid      = "ReadVpcFlowLogsNativeQueue"
        Effect   = "Allow"
        Action   = ["sqs:ReceiveMessage", "sqs:DeleteMessage", "sqs:GetQueueAttributes"]
        Resource = var.vpc_flow_logs_native_sqs_queue_arn
      },
    ]
  })
}

# Holds installer bundles (e.g. the TA-aws Splunk app) that can't be fetched
# directly from their origin during provisioning — Splunkbase requires a
# splunk.com login to download, which a headless user_data script can't do.
# Upload manually: aws s3 cp <file>.spl s3://<bucket>/apps/<file>.spl
resource "aws_s3_bucket" "app_bundles" {
  bucket = "${var.name}-app-bundles-${data.aws_caller_identity.current.account_id}"
  tags   = merge({ Name = "${var.name}-app-bundles", ManagedBy = "terraform" }, var.tags)
}

resource "aws_s3_bucket_public_access_block" "app_bundles" {
  bucket = aws_s3_bucket.app_bundles.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "app_bundles" {
  bucket = aws_s3_bucket.app_bundles.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_iam_role_policy" "read_app_bundles" {
  name = "read-app-bundles"
  role = aws_iam_role.splunk.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadAppBundlesBucket"
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]
      Resource = [aws_s3_bucket.app_bundles.arn, "${aws_s3_bucket.app_bundles.arn}/*"]
    }]
  })
}

# SSM Session Manager instead of SSH — no key pair, no open port 22.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.splunk.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "splunk" {
  name = "${var.name}-profile"
  role = aws_iam_role.splunk.name
}

resource "aws_instance" "splunk" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  # null (default, no availability_zone pin) lets AWS pick whichever AZ/default
  # subnet currently has capacity — t3.small InsufficientInstanceCapacity has
  # flipped between 7a/7b/7c on different days, so pinning one AZ is fragile.
  subnet_id                   = var.availability_zone != null ? data.aws_subnets.default_public.ids[0] : null
  vpc_security_group_ids      = [aws_security_group.splunk.id]
  iam_instance_profile        = aws_iam_instance_profile.splunk.name
  associate_public_ip_address = true

  dynamic "instance_market_options" {
    for_each = var.use_spot ? [1] : []
    content {
      market_type = "spot"
      spot_options {
        max_price = var.spot_max_price
      }
    }
  }

  root_block_device {
    volume_size           = var.root_volume_size_gb
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  # base64gzip (not base64encode): EC2/cloud-init auto-decompresses gzip
  # user_data, and this script keeps growing as more pollers get added — plain
  # base64 already crossed the 16384-byte hard limit at 4 pollers.
  user_data = base64gzip(templatefile("${path.module}/user_data.sh.tpl", {
    splunk_admin_password              = random_password.splunk_admin.result
    splunk_download_url                = var.splunk_download_url
    aws_region                         = data.aws_region.current.name
    cloudtrail_role_arn                = var.cloudtrail_role_arn
    cloudtrail_log_group_name          = var.cloudtrail_log_group_name
    securityhub_export_bucket_name     = var.securityhub_export_bucket_name
    logs_central_bucket_name           = var.logs_central_bucket_name
    app_bundles_bucket_name            = aws_s3_bucket.app_bundles.bucket
    ta_aws_package_s3_key              = var.ta_aws_package_s3_key
    splunk_role_name                   = aws_iam_role.splunk.name
    vpc_flow_logs_native_sqs_queue_url = var.vpc_flow_logs_native_sqs_queue_url
    cloudwatch_metrics_targets         = var.cloudwatch_metrics_targets
  }))
  # user_data only runs on first boot — without this, changing splunk_download_url
  # (e.g. after a dead link) would update state but never actually reinstall Splunk.
  user_data_replace_on_change = true

  tags = merge({ Name = var.name, ManagedBy = "terraform" }, var.tags)

  lifecycle {
    # most_recent AMI lookup can resolve to a newer image between applies (AL2023
    # refreshes often) and silently force-replace a perfectly fine running instance.
    # Pin to whatever AMI/subnet is actually running; change deliberately via -replace.
    #
    # associate_public_ip_address: AWS doesn't reliably report back whether this was
    # explicitly requested vs. inherited from the subnet's auto-assign default, so it
    # can drift to a forced-replacement plan even though the instance already has a
    # public IP and nothing is actually wrong — replacing this instance would delete
    # its EBS volume (delete_on_termination=true) and all indexed Splunk data with it.
    ignore_changes = [ami, subnet_id, associate_public_ip_address]
  }
}
