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
