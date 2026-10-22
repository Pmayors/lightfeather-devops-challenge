resource "aws_ecs_cluster" "this" {
  name = var.project

  setting {
    name  = "containerInsights"
    value = "disabled"
  }

  tags = {
    Name = var.project
  }
}

resource "aws_cloudwatch_log_group" "app" {
  for_each = local.services

  name              = "/ecs/${var.project}/${each.value.environment}/${each.value.app}"
  retention_in_days = 7

  tags = {
    Name        = "${var.project}-${each.key}"
    Environment = each.value.environment
  }
}

resource "aws_ecs_task_definition" "app" {
  for_each = local.services

  family                   = "${var.project}-${each.key}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.execution.arn
  task_role_arn            = aws_iam_role.task.arn

  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture        = "X86_64"
  }

  container_definitions = jsonencode([
    {
      name      = each.value.app
      image     = each.value.image
      essential = true
      portMappings = [
        {
          containerPort = each.value.port
          protocol      = "tcp"
        }
      ]
      environment = each.value.app == "backend" ? [
        {
          name  = "CORS_ORIGIN"
          value = "http://${aws_lb.app.dns_name}"
        },
        {
          name  = "PORT"
          value = "8080"
        }
      ] : []
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = aws_cloudwatch_log_group.app[each.key].name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = each.value.app
        }
      }
    }
  ])

  tags = {
    Name        = "${var.project}-${each.key}"
    Environment = each.value.environment
  }
}

resource "aws_ecs_service" "app" {
  for_each = local.services

  name            = "${var.project}-${each.key}"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app[each.key].arn
  desired_count   = each.value.desired_count
  launch_type     = "FARGATE"

  # A running service must keep serving during a rolling update only when more
  # than one task is affordable. With a single task, allow the old one to stop
  # so a deploy does not briefly run two copies.
  deployment_minimum_healthy_percent = 0
  deployment_maximum_percent         = 200

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = each.value.subnet_ids
    security_groups  = [aws_security_group.task[each.key].id]
    assign_public_ip = !var.place_tasks_in_private_subnets
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.app[each.key].arn
    container_name   = each.value.app
    container_port   = each.value.port
  }

  health_check_grace_period_seconds = 60

  # The pipeline registers a new task definition revision for each image tag
  # and sets the running count. Terraform keeps the service, network, and load
  # balancer wiring, and must not roll those back on the next apply.
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }

  depends_on = [
    aws_lb_listener_rule.api,
    aws_lb_listener_rule.frontend,
    aws_iam_role_policy_attachment.execution
  ]

  tags = {
    Name        = "${var.project}-${each.key}"
    Environment = each.value.environment
  }
}
