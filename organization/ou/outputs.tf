output "organizational_units" {
  description = "Map of created OUs with id, arn, name, and parent_id keyed by input map key"
  value = {
    for k, ou in aws_organizations_organizational_unit.this : k => {
      id        = ou.id
      arn       = ou.arn
      name      = ou.name
      parent_id = ou.parent_id
    }
  }
}

output "ids" {
  description = "Map of OU key to OU ID — use as parent_id for account or SCP modules"
  value       = { for k, ou in aws_organizations_organizational_unit.this : k => ou.id }
}

output "arns" {
  description = "Map of OU key to OU ARN — use as target_identifier for CT controls or SCP attachments"
  value       = { for k, ou in aws_organizations_organizational_unit.this : k => ou.arn }
}
