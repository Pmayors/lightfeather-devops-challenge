# I put dev, stage, and prod in one VPC in us-east-1.
# Each environment gets one public subnet, one private subnet, and two ECS services.
# Images sit in ECR. One load balancer splits them by path so I do not pay for three.

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

module "ecr" {
  source = "./modules/ecr"

  project      = var.project
  repositories = toset(["backend", "frontend"])
}

module "ecs" {
  source = "./modules/ecs"

  project                        = var.project
  aws_region                     = var.aws_region
  vpc_id                         = module.network.vpc_id
  vpc_cidr                       = module.network.vpc_cidr
  public_subnet_ids              = module.network.public_subnet_ids
  private_subnet_ids             = module.network.private_subnet_ids
  alb_subnet_ids                 = values(module.network.public_subnet_ids)
  repository_urls                = module.ecr.repository_urls
  image_tag                      = var.image_tag
  environments                   = var.environments
  place_tasks_in_private_subnets = var.place_tasks_in_private_subnets
}
