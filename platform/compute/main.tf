resource "aws_launch_template" "this" {
  for_each = var.launch_templates

  name_prefix   = "${each.value.name}-"
  image_id      = each.value.ami_id
  instance_type = each.value.instance_type
  key_name      = each.value.key_name
  user_data     = each.value.user_data != null ? base64encode(each.value.user_data) : null

  vpc_security_group_ids = each.value.security_group_ids

  dynamic "iam_instance_profile" {
    for_each = each.value.iam_instance_profile_arn != null ? [1] : []
    content {
      arn = each.value.iam_instance_profile_arn
    }
  }

  dynamic "block_device_mappings" {
    for_each = each.value.root_volume != null ? [each.value.root_volume] : []
    content {
      device_name = "/dev/xvda"
      ebs {
        volume_size           = block_device_mappings.value.size_gb
        volume_type           = block_device_mappings.value.type
        encrypted             = true
        delete_on_termination = true
        kms_key_id            = block_device_mappings.value.kms_key_arn
      }
    }
  }

  # Enforce IMDSv2 — prevents SSRF-based metadata credential theft
  metadata_options {
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = each.value.enable_detailed_monitoring
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge({ Name = each.value.name, ManagedBy = "terraform" }, var.tags, each.value.tags)
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge({ Name = each.value.name, ManagedBy = "terraform" }, var.tags, each.value.tags)
  }

  tags = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "this" {
  for_each = var.autoscaling_groups

  name                      = each.value.name
  min_size                  = each.value.min_size
  max_size                  = each.value.max_size
  desired_capacity          = each.value.desired_capacity
  vpc_zone_identifier       = each.value.subnet_ids
  health_check_type         = each.value.health_check_type
  health_check_grace_period = each.value.health_check_grace_period
  wait_for_capacity_timeout = "0"

  launch_template {
    id      = aws_launch_template.this[each.value.launch_template_key].id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = merge({ Name = each.value.name, ManagedBy = "terraform" }, var.tags, each.value.tags)
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    ignore_changes = [desired_capacity]
  }
}
