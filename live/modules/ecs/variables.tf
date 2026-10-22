variable "project" {
  description = "Name prefix shared with the network and ECR modules."
  type        = string
}

variable "aws_region" {
  description = "Region used by the awslogs driver."
  type        = string
}

variable "vpc_id" {
  description = "VPC for the load balancer and tasks."
  type        = string
}

variable "vpc_cidr" {
  description = "VPC CIDR. Task security groups allow DNS only inside this range."
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet id keyed by environment."
  type        = map(string)
}

variable "private_subnet_ids" {
  description = "Private subnet id keyed by environment."
  type        = map(string)
}

variable "alb_subnet_ids" {
  description = "At least two public subnets in different availability zones for the load balancer."
  type        = list(string)
}

variable "repository_urls" {
  description = "ECR repository URL keyed by application name."
  type        = map(string)
}

variable "image_tag" {
  description = "Image tag referenced by the Terraform-managed task definition."
  type        = string
}

variable "place_tasks_in_private_subnets" {
  description = "Select the private subnet for each environment instead of the public one."
  type        = bool
}

variable "task_cpu" {
  description = "Fargate task CPU units. 256 is the smallest."
  type        = string
  default     = "256"
}

variable "task_memory" {
  description = "Fargate task memory in MiB. 512 is the smallest value allowed with 256 CPU."
  type        = string
  default     = "512"
}

variable "environments" {
  description = "Environments to run. Only desired_count is read from each entry."
  type = map(object({
    public_cidr   = string
    private_cidr  = string
    az_index      = number
    desired_count = number
  }))
}
