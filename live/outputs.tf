output "vpc_id" {
  description = "VPC that holds dev, stage, and prod."
  value       = module.network.vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet id for each environment."
  value       = module.network.public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet id for each environment."
  value       = module.network.private_subnet_ids
}

output "ecr_repository_urls" {
  description = "Push the backend and frontend images here."
  value       = module.ecr.repository_urls
}

output "ecs_cluster_name" {
  description = "Cluster name. Matches the PROJECT parameter in the application pipeline."
  value       = module.ecs.cluster_name
}

output "alb_dns_name" {
  description = "Public DNS name of the shared load balancer."
  value       = module.ecs.alb_dns_name
}

output "environment_urls" {
  description = "Browser URL for each environment once its tasks are running."
  value = {
    for name in keys(var.environments) :
    name => "http://${module.ecs.alb_dns_name}/${name}/"
  }
}

output "service_names" {
  description = "ECS service names the Jenkins deploy stages update."
  value       = module.ecs.service_names
}
