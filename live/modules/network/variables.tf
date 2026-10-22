variable "project" {
  description = "Name prefix for the VPC and subnets."
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
}

variable "enable_nat_gateway" {
  description = "When true, one NAT gateway serves every private subnet."
  type        = bool
}

variable "nat_subnet_key" {
  description = "Environment whose public subnet holds the NAT gateway."
  type        = string
}

variable "environments" {
  description = "Subnet layout for each environment."
  type = map(object({
    public_cidr  = string
    private_cidr = string
    az_index     = number
  }))
}
