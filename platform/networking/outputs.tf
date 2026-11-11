output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Map of public subnet key to subnet ID"
  value       = { for k, s in aws_subnet.public : k => s.id }
}

output "private_subnet_ids" {
  description = "Map of private subnet key to subnet ID"
  value       = { for k, s in aws_subnet.private : k => s.id }
}

output "public_subnet_id_list" {
  description = "List of all public subnet IDs"
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_id_list" {
  description = "List of all private subnet IDs"
  value       = [for s in aws_subnet.private : s.id]
}

output "nat_gateway_ids" {
  description = "Map of NAT GW key to NAT GW ID"
  value       = { for k, n in aws_nat_gateway.this : k => n.id }
}

output "nat_gateway_public_ips" {
  description = "Map of NAT GW key to public EIP"
  value       = { for k, e in aws_eip.nat : k => e.public_ip }
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = length(aws_internet_gateway.this) > 0 ? aws_internet_gateway.this[0].id : null
}
