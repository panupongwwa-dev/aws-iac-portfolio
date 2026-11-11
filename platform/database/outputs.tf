output "db_instance_ids" {
  description = "Map of DB instance key to instance ID"
  value       = { for k, db in aws_db_instance.this : k => db.id }
}

output "db_instance_arns" {
  description = "Map of DB instance key to ARN"
  value       = { for k, db in aws_db_instance.this : k => db.arn }
}

output "db_instance_endpoints" {
  description = "Map of DB instance key to connection endpoint"
  value       = { for k, db in aws_db_instance.this : k => db.endpoint }
}

output "db_instance_addresses" {
  description = "Map of DB instance key to hostname"
  value       = { for k, db in aws_db_instance.this : k => db.address }
}

output "db_instance_ports" {
  description = "Map of DB instance key to port"
  value       = { for k, db in aws_db_instance.this : k => db.port }
}

output "db_subnet_group_ids" {
  description = "Map of subnet group key to ID"
  value       = { for k, sg in aws_db_subnet_group.this : k => sg.id }
}
