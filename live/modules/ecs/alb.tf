resource "aws_lb" "app" {
  name                       = var.project
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = var.alb_subnet_ids
  drop_invalid_header_fields = true
  enable_deletion_protection = false

  tags = {
    Name = var.project
  }
}

resource "aws_lb_target_group" "app" {
  for_each = local.services

  name                 = "${var.project}-${each.key}"
  port                 = each.value.port
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "ip"
  deregistration_delay = 30

  health_check {
    path                = each.value.health_check_path
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }

  tags = {
    Name        = "${var.project}-${each.key}"
    Environment = each.value.environment
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Open /dev/, /stage/, or /prod/."
      status_code  = "404"
    }
  }
}

resource "aws_lb_listener_rule" "api" {
  for_each = var.environments

  listener_arn = aws_lb_listener.http.arn
  priority     = local.environment_priority[each.key]

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app["${each.key}-backend"].arn
  }

  condition {
    path_pattern {
      values = ["/${each.key}/api", "/${each.key}/api/*"]
    }
  }
}

resource "aws_lb_listener_rule" "frontend" {
  for_each = var.environments

  listener_arn = aws_lb_listener.http.arn
  priority     = local.environment_priority[each.key] + 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app["${each.key}-frontend"].arn
  }

  condition {
    path_pattern {
      values = ["/${each.key}", "/${each.key}/*"]
    }
  }
}
