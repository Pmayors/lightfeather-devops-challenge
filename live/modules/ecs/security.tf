resource "aws_security_group" "alb" {
  name        = "${var.project}-alb"
  description = "HTTP entry point for the shared application load balancer"
  vpc_id      = var.vpc_id

  tags = {
    Name = "${var.project}-alb"
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the internet"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  to_port           = 80
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_task" {
  for_each = local.services

  security_group_id            = aws_security_group.alb.id
  description                  = "Forward to ${each.key}"
  referenced_security_group_id = aws_security_group.task[each.key].id
  from_port                    = each.value.port
  to_port                      = each.value.port
  ip_protocol                  = "tcp"
}

resource "aws_security_group" "task" {
  for_each = local.services

  name        = "${var.project}-${each.key}"
  description = "ECS task ${each.key}"
  vpc_id      = var.vpc_id

  tags = {
    Name        = "${var.project}-${each.key}"
    Environment = each.value.environment
  }
}

resource "aws_vpc_security_group_ingress_rule" "task_from_alb" {
  for_each = local.services

  security_group_id            = aws_security_group.task[each.key].id
  description                  = "Application traffic from the load balancer"
  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = each.value.port
  to_port                      = each.value.port
  ip_protocol                  = "tcp"
}

# Tasks have a public IP so they can reach ECR and CloudWatch without a NAT
# gateway. Ingress is still only the load balancer. DNS stays inside the VPC.
resource "aws_vpc_security_group_egress_rule" "task_dns_udp" {
  for_each = local.services

  security_group_id = aws_security_group.task[each.key].id
  description       = "DNS to the VPC resolver"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "udp"
}

resource "aws_vpc_security_group_egress_rule" "task_dns_tcp" {
  for_each = local.services

  security_group_id = aws_security_group.task[each.key].id
  description       = "DNS to the VPC resolver over TCP"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 53
  to_port           = 53
  ip_protocol       = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "task_https" {
  for_each = local.services

  security_group_id = aws_security_group.task[each.key].id
  description       = "HTTPS for ECR and CloudWatch Logs"
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 443
  to_port           = 443
  ip_protocol       = "tcp"
}
