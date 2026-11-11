variable "name" {
  description = "Name prefix for all networking resources"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "enable_dns_hostnames" {
  description = "Enable DNS hostnames in the VPC"
  type        = bool
  default     = true
}

variable "public_subnets" {
  description = "Map of public subnets to create"
  type = map(object({
    cidr          = string
    az            = string
    map_public_ip = optional(bool, true)
    tags          = optional(map(string), {})
  }))
  default = {}
}

variable "private_subnets" {
  description = "Map of private subnets to create"
  type = map(object({
    cidr = string
    az   = string
    tags = optional(map(string), {})
  }))
  default = {}
}

variable "enable_nat_gateway" {
  description = "Create NAT gateway(s) for private subnet internet access"
  type        = bool
  default     = true
}

variable "single_nat_gateway" {
  description = "Use a single NAT GW (cost-efficient for dev). When false, creates one NAT GW per AZ."
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
