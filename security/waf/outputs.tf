output "web_acl_arns" {
  description = "Map of Web ACL name to ARN"
  value       = { for k, w in aws_wafv2_web_acl.this : k => w.arn }
}

output "web_acl_ids" {
  description = "Map of Web ACL name to ID"
  value       = { for k, w in aws_wafv2_web_acl.this : k => w.id }
}

output "web_acl_capacities" {
  description = "Map of Web ACL name to consumed WCU capacity"
  value       = { for k, w in aws_wafv2_web_acl.this : k => w.capacity }
}
