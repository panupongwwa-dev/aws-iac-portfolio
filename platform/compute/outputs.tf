output "launch_template_ids" {
  description = "Map of launch template key to ID"
  value       = { for k, lt in aws_launch_template.this : k => lt.id }
}

output "launch_template_arns" {
  description = "Map of launch template key to ARN"
  value       = { for k, lt in aws_launch_template.this : k => lt.arn }
}

output "launch_template_latest_versions" {
  description = "Map of launch template key to latest version number"
  value       = { for k, lt in aws_launch_template.this : k => lt.latest_version }
}

output "autoscaling_group_names" {
  description = "Map of ASG key to ASG name"
  value       = { for k, asg in aws_autoscaling_group.this : k => asg.name }
}

output "autoscaling_group_arns" {
  description = "Map of ASG key to ASG ARN"
  value       = { for k, asg in aws_autoscaling_group.this : k => asg.arn }
}
