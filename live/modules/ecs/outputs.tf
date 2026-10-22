output "cluster_name" {
  description = "ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "alb_dns_name" {
  description = "DNS name of the application load balancer."
  value       = aws_lb.app.dns_name
}

output "service_names" {
  description = "ECS service name keyed by environment-application."
  value       = { for key, service in aws_ecs_service.app : key => service.name }
}
