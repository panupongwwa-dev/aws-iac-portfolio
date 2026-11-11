resource "aws_db_subnet_group" "this" {
  for_each = var.db_subnet_groups

  name       = each.key
  subnet_ids = each.value.subnet_ids
  tags       = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)
}

resource "aws_db_parameter_group" "this" {
  for_each = var.db_parameter_groups

  name   = each.key
  family = each.value.family

  dynamic "parameter" {
    for_each = each.value.parameters
    content {
      name  = parameter.key
      value = parameter.value
    }
  }

  tags = merge({ ManagedBy = "terraform" }, var.tags, each.value.tags)

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_db_instance" "this" {
  for_each = var.db_instances

  identifier     = each.key
  engine         = each.value.engine
  engine_version = each.value.engine_version
  instance_class = each.value.instance_class

  allocated_storage     = each.value.allocated_storage
  max_allocated_storage = each.value.max_allocated_storage
  storage_type          = each.value.storage_type
  storage_encrypted     = true
  kms_key_id            = each.value.kms_key_arn

  db_name  = each.value.db_name
  username = each.value.username
  password = each.value.password

  manage_master_user_password = each.value.password == null ? true : null

  db_subnet_group_name   = each.value.subnet_group_key != null ? aws_db_subnet_group.this[each.value.subnet_group_key].name : each.value.subnet_group_name
  parameter_group_name   = each.value.parameter_group_key != null ? aws_db_parameter_group.this[each.value.parameter_group_key].name : each.value.parameter_group_name
  vpc_security_group_ids = each.value.security_group_ids

  multi_az                  = each.value.multi_az
  publicly_accessible       = false
  deletion_protection       = each.value.deletion_protection
  skip_final_snapshot       = each.value.skip_final_snapshot
  final_snapshot_identifier = each.value.skip_final_snapshot ? null : "${each.key}-final-snapshot"

  backup_retention_period = each.value.backup_retention_period
  backup_window           = each.value.backup_window
  maintenance_window      = each.value.maintenance_window
  copy_tags_to_snapshot   = true

  tags = merge({ Name = each.key, ManagedBy = "terraform" }, var.tags, each.value.tags)

  lifecycle {
    ignore_changes = [password]
  }
}
