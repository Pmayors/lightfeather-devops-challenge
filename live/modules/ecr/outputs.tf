output "repository_urls" {
  description = "Map of application name to repository URL."
  value       = { for name, repo in aws_ecr_repository.this : name => repo.repository_url }
}

output "repository_names" {
  description = "Map of application name to repository name."
  value       = { for name, repo in aws_ecr_repository.this : name => repo.name }
}
