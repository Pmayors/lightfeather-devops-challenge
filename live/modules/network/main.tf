data "aws_availability_zones" "available" {
  state = "available"

  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  availability_zones = data.aws_availability_zones.available.names
}

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = var.project
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = var.project
  }
}

resource "aws_subnet" "public" {
  for_each = var.environments

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.public_cidr
  availability_zone       = local.availability_zones[each.value.az_index]
  map_public_ip_on_launch = true

  tags = {
    Name        = "${var.project}-${each.key}-public"
    Environment = each.key
    Tier        = "public"
  }
}

resource "aws_subnet" "private" {
  for_each = var.environments

  vpc_id                  = aws_vpc.this.id
  cidr_block              = each.value.private_cidr
  availability_zone       = local.availability_zones[each.value.az_index]
  map_public_ip_on_launch = false

  tags = {
    Name        = "${var.project}-${each.key}-private"
    Environment = each.key
    Tier        = "private"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project}-public"
  }
}

resource "aws_route" "public_internet" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.this.id
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Private subnets have only the VPC local route unless a NAT gateway is turned on.
# That keeps the default stack off the NAT hourly charge. ECS tasks therefore
# start in the public subnets, with ingress limited to the load balancer.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project}-private"
  }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

resource "aws_eip" "nat" {
  count = var.enable_nat_gateway ? 1 : 0

  domain = "vpc"

  tags = {
    Name = "${var.project}-nat"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_nat_gateway" "this" {
  count = var.enable_nat_gateway ? 1 : 0

  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public[var.nat_subnet_key].id

  tags = {
    Name = var.project
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_route" "private_nat" {
  count = var.enable_nat_gateway ? 1 : 0

  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.this[0].id
}
