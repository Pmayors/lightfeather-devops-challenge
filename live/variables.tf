variable "aws_region" {
  description = "Region for every resource. The challenge is written for us-east-1."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Short name used as a prefix on resources. Jenkins uses the same value."
  type        = string
  default     = "lightfeather"

  validation {
    condition     = length(var.project) <= 16 && can(regex("^[a-z][a-z0-9-]*[a-z0-9]$", var.project))
    error_message = "Use 2 to 16 characters: start with a letter, then lowercase letters, numbers, or hyphens. This keeps ALB and target group names inside the 32 character AWS limit."
  }
}

variable "vpc_cidr" {
  description = "CIDR for the single VPC shared by dev, stage, and prod."
  type        = string
  default     = "10.0.0.0/16"
}

variable "image_tag" {
  description = "Tag of the image the first task definition points at. Jenkins replaces the running revision after it pushes a real tag."
  type        = string
  default     = "initial"
}

variable "enable_nat_gateway" {
  description = "Create one NAT gateway for the private subnets. Leave false to stay off the hourly NAT charge."
  type        = bool
  default     = false
}

variable "place_tasks_in_private_subnets" {
  description = "Run ECS tasks in the private subnets. Requires enable_nat_gateway so tasks can pull from ECR."
  type        = bool
  default     = false
}

variable "environments" {
  description = "One public subnet and one private subnet are created for each entry. desired_count stays 0 until an image exists; the application pipeline raises it."
  type = map(object({
    public_cidr   = string
    private_cidr  = string
    az_index      = number
    desired_count = number
  }))
  default = {
    dev = {
      public_cidr   = "10.0.0.0/24"
      private_cidr  = "10.0.10.0/24"
      az_index      = 0
      desired_count = 0
    }
    stage = {
      public_cidr   = "10.0.1.0/24"
      private_cidr  = "10.0.11.0/24"
      az_index      = 1
      desired_count = 0
    }
    prod = {
      public_cidr   = "10.0.2.0/24"
      private_cidr  = "10.0.12.0/24"
      az_index      = 2
      desired_count = 0
    }
  }
}
