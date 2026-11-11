locals {
  # Map: AZ → first public subnet key in that AZ (for NAT GW placement)
  az_to_public_key = {
    for az in distinct([for k, v in var.public_subnets : v.az]) :
    az => [for k, v in var.public_subnets : k if v.az == az][0]
  }

  # Public subnet keys that receive a NAT GW: all AZs (multi) or first AZ (single)
  nat_keys = toset(
    !var.enable_nat_gateway ? [] :
    var.single_nat_gateway ? slice(values(local.az_to_public_key), 0, 1) :
    values(local.az_to_public_key)
  )

  # Distinct AZs used by private subnets (one route table per AZ)
  private_azs = toset(distinct([for k, v in var.private_subnets : v.az]))
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = true
  tags                 = merge({ Name = var.name, ManagedBy = "terraform" }, var.tags)
}

resource "aws_internet_gateway" "this" {
  count  = length(var.public_subnets) > 0 ? 1 : 0
  vpc_id = aws_vpc.this.id
  tags   = merge({ Name = var.name, ManagedBy = "terraform" }, var.tags)
}

resource "aws_subnet" "public" {
  for_each = var.public_subnets

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.cidr
  availability_zone       = each.value.az
  map_public_ip_on_launch = each.value.map_public_ip

  tags = merge({ Name = "${var.name}-${each.key}", ManagedBy = "terraform" }, var.tags, each.value.tags)
}

resource "aws_subnet" "private" {
  for_each = var.private_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = merge({ Name = "${var.name}-${each.key}", ManagedBy = "terraform" }, var.tags, each.value.tags)
}

resource "aws_eip" "nat" {
  for_each   = local.nat_keys
  domain     = "vpc"
  depends_on = [aws_internet_gateway.this]
  tags       = merge({ Name = "${var.name}-nat-${each.key}", ManagedBy = "terraform" }, var.tags)
}

resource "aws_nat_gateway" "this" {
  for_each      = local.nat_keys
  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = aws_subnet.public[each.key].id
  tags          = merge({ Name = "${var.name}-nat-${each.key}", ManagedBy = "terraform" }, var.tags)
  depends_on    = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  count  = length(var.public_subnets) > 0 ? 1 : 0
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this[0].id
  }

  tags = merge({ Name = "${var.name}-public", ManagedBy = "terraform" }, var.tags)
}

resource "aws_route_table_association" "public" {
  for_each       = var.public_subnets
  subnet_id      = aws_subnet.public[each.key].id
  route_table_id = aws_route_table.public[0].id
}

# One private route table per AZ; routes to the matching NAT GW (or single NAT GW)
resource "aws_route_table" "private" {
  for_each = local.private_azs
  vpc_id   = aws_vpc.this.id

  dynamic "route" {
    for_each = var.enable_nat_gateway ? [1] : []
    content {
      cidr_block = "0.0.0.0/0"
      nat_gateway_id = (
        var.single_nat_gateway
        ? aws_nat_gateway.this[tolist(local.nat_keys)[0]].id
        : aws_nat_gateway.this[try(local.az_to_public_key[each.key], tolist(local.nat_keys)[0])].id
      )
    }
  }

  tags = merge({ Name = "${var.name}-private-${each.key}", ManagedBy = "terraform" }, var.tags)
}

resource "aws_route_table_association" "private" {
  for_each       = var.private_subnets
  subnet_id      = aws_subnet.private[each.key].id
  route_table_id = aws_route_table.private[each.value.az].id
}

# Lock down the default security group (deny all) — security best practice
resource "aws_default_security_group" "this" {
  vpc_id = aws_vpc.this.id
  tags   = merge({ Name = "${var.name}-default-restricted", ManagedBy = "terraform" }, var.tags)
}
