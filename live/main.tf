# Infrastructure for the LightFeather challenge.
# One VPC in us-east-1, shared by dev, stage, and prod.
# Each environment gets one public subnet and one private subnet.
# Private subnets have no default route unless a NAT gateway is turned on.

check "private_tasks_need_nat" {
  assert {
    condition     = !var.place_tasks_in_private_subnets || var.enable_nat_gateway
    error_message = "Tasks in private subnets need a NAT gateway so they can pull from ECR and write logs."
  }
}

module "network" {
  source = "./modules/network"

  project            = var.project
  vpc_cidr           = var.vpc_cidr
  enable_nat_gateway = var.enable_nat_gateway
  nat_subnet_key     = "dev"
  environments = {
    for name, cfg in var.environments : name => {
      public_cidr  = cfg.public_cidr
      private_cidr = cfg.private_cidr
      az_index     = cfg.az_index
    }
  }
}
