output "vpc_id" {
  description = "ID of the VPC."
  value       = aws_vpc.this.id
}

output "vpc_cidr" {
  description = "CIDR of the VPC."
  value       = aws_vpc.this.cidr_block
}

output "public_subnet_ids" {
  description = "Map of environment name to public subnet id."
  value       = { for key, subnet in aws_subnet.public : key => subnet.id }
}

output "private_subnet_ids" {
  description = "Map of environment name to private subnet id."
  value       = { for key, subnet in aws_subnet.private : key => subnet.id }
}
