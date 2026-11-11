# =============================================================================
# platform/grafana-poc — single-node Grafana on EC2 (t3.nano default), reading
# Lambda/other CloudWatch metrics via the built-in CloudWatch data source.
# No local data storage — Grafana queries CloudWatch live, so this box can be
# tiny. Cross-account metrics (e.g. a workload dev account) go through the same
# assume-role pattern as security/splunk-poc's CloudTrail reader.
# =============================================================================

data "aws_region" "current" {}

locals {
  # Each cross-account role becomes its own Grafana CloudWatch data source,
  # named by account ID so dashboards can tell which account a panel reads from.
  cross_account_datasources = [
    for arn in var.cross_account_metrics_role_arns : {
      arn        = arn
      account_id = regex("::([0-9]{12}):", arn)[0]
    }
  ]
}

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

resource "random_password" "grafana_admin" {
  length  = 20
  special = false
}

resource "aws_secretsmanager_secret" "grafana_admin" {
  name        = "${var.name}/grafana-admin-password"
  description = "Auto-generated Grafana admin password for ${var.name}"
  tags        = merge({ ManagedBy = "terraform" }, var.tags)
}

resource "aws_secretsmanager_secret_version" "grafana_admin" {
  secret_id     = aws_secretsmanager_secret.grafana_admin.id
  secret_string = random_password.grafana_admin.result
}

resource "aws_security_group" "grafana" {
  name        = var.name
  description = "Grafana POC - web UI access only, no inbound SSH (use SSM Session Manager)"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Grafana Web UI"
    from_port   = 3000
    to_port     = 3000
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

resource "aws_iam_role" "grafana" {
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

# Read-only CloudWatch access for THIS account's own metrics (the CloudWatch
# data source's built-in default region/account, before any cross-account
# assume-role data sources are layered on top).
resource "aws_iam_role_policy" "cloudwatch_read" {
  name = "cloudwatch-read"
  role = aws_iam_role.grafana.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "CloudWatchRead"
      Effect = "Allow"
      Action = [
        "cloudwatch:GetMetricData",
        "cloudwatch:GetMetricStatistics",
        "cloudwatch:ListMetrics",
        "cloudwatch:DescribeAlarmsForMetric",
        "tag:GetResources",
      ]
      Resource = "*"
    }]
  })
}

# Lets the instance fetch its own admin password (used to set it via grafana-cli on boot).
resource "aws_iam_role_policy" "read_own_secret" {
  name = "read-own-secret"
  role = aws_iam_role.grafana.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadOwnGrafanaAdminSecret"
      Effect   = "Allow"
      Action   = "secretsmanager:GetSecretValue"
      Resource = aws_secretsmanager_secret.grafana_admin.arn
    }]
  })
}

# Cross-account roles this instance may assume to read CloudWatch metrics in
# other accounts (e.g. a workload account's Lambda metrics).
resource "aws_iam_role_policy" "assume_cross_account_roles" {
  count = length(var.cross_account_metrics_role_arns) > 0 ? 1 : 0
  name  = "assume-cross-account-metrics-roles"
  role  = aws_iam_role.grafana.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "AssumeCrossAccountMetricsRoles"
      Effect   = "Allow"
      Action   = "sts:AssumeRole"
      Resource = var.cross_account_metrics_role_arns
    }]
  })
}

# SSM Session Manager instead of SSH — no key pair, no open port 22.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.grafana.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "grafana" {
  name = "${var.name}-profile"
  role = aws_iam_role.grafana.name
}

resource "aws_instance" "grafana" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  # null (default, no availability_zone pin) lets AWS pick whichever AZ/default
  # subnet currently has capacity — see security/splunk-poc for why pinning is fragile here.
  subnet_id                   = var.availability_zone != null ? data.aws_subnets.default_public.ids[0] : null
  vpc_security_group_ids      = [aws_security_group.grafana.id]
  iam_instance_profile        = aws_iam_instance_profile.grafana.name
  associate_public_ip_address = true

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

  # base64gzip (not base64encode): see security/splunk-poc's user_data for why
  # — EC2/cloud-init auto-decompresses gzip user_data, and plain base64 hits a
  # hard 16384-byte limit faster than expected once you add cross-account
  # datasource provisioning.
  user_data = base64gzip(templatefile("${path.module}/user_data.sh.tpl", {
    grafana_admin_password    = random_password.grafana_admin.result
    grafana_download_url      = var.grafana_download_url
    aws_region                = data.aws_region.current.name
    cross_account_datasources = local.cross_account_datasources
  }))
  user_data_replace_on_change = true

  tags = merge({ Name = var.name, ManagedBy = "terraform" }, var.tags)

  lifecycle {
    # associate_public_ip_address: see security/splunk-poc's aws_instance for why
    # this drifts to a forced-replacement plan even when nothing is actually wrong.
    ignore_changes = [ami, subnet_id, associate_public_ip_address]
  }
}
