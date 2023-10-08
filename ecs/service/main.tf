resource "aws_lb_target_group" "main" {
  count       = length(var.services)
  name        = "${var.name}-tg-${lookup(var.services[count.index], "name", null)}-${var.environment}"
  port        = 80 # lookup(var.services[count.index], "port", 80)
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval            = "30"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "3"
    path                = lookup(var.services[count.index], "health", null)
    unhealthy_threshold = "2"
  }

  tags = {
    Name        = "${var.name}-tg-${lookup(var.services[count.index], "name", null)}-${var.environment}"
    Environment = var.environment
  }
}

# Redirect to https listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = var.aws_lb_arn
  port              = 80
  protocol          = "HTTP"

  # default_action {
  #   type = "redirect"

  #   redirect {
  #     port        = 443
  #     protocol    = "HTTPS"
  #     status_code = "HTTP_301"
  #   }
  # }
  default_action {
    target_group_arn = aws_lb_target_group.main[0].id
    type             = "forward"
  }
}

resource "aws_lb_listener_rule" "main" {
  count        = length(var.services) > 0 ? length(var.services) : 0
  listener_arn = aws_lb_listener.http.arn
  priority     = lookup(var.services[count.index], "priority", 100)

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main[count.index].arn
  }

  condition {
    path_pattern {
      values = [lookup(var.services[count.index], "context", "/")]
    }
  }
}


# Redirect traffic to target group
# resource "aws_lb_listener" "https" {
#   load_balancer_arn = aws_lb.main.id
#   port              = 443
#   protocol          = "HTTPS"

#   ssl_policy = "ELBSecurityPolicy-2016-08"
#   # certificate_arn   = var.alb_tls_cert_arn

#   default_action {
#     target_group_arn = aws_lb_target_group.main.id
#     type             = "forward"
#   }
# }


resource "aws_ecs_task_definition" "main" {
  count                    = length(var.services) > 0 ? length(var.services) : 0
  family                   = "${var.name}-${lookup(var.services[count.index], "name", null)}-task-${var.environment}"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = lookup(var.services[count.index], "cpu", 512)
  memory                   = lookup(var.services[count.index], "memory", 256)
  execution_role_arn       = var.ecs_task_execution_role_arn
  task_role_arn            = var.ecs_task_role_arn
  container_definitions = jsonencode([{
    name        = "${var.name}-${lookup(var.services[count.index], "name", null)}-container-${var.environment}"
    image       = local.image_urls[count.index]
    essential   = true
    environment = var.container_environment
    portMappings = [{
      protocol      = "tcp"
      containerPort = lookup(var.services[count.index], "port", 80)
      # hostPort      = lookup(var.services[count.index], "port", 80)
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.main[count.index].name
        awslogs-stream-prefix = "ecs"
        awslogs-region        = var.region
      }
    }
    secrets = var.container_secrets
  }])

  tags = {
    Name        = "${var.name}-${lookup(var.services[count.index], "name", null)}-task-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_ecs_service" "main" {
  count                              = length(var.services) > 0 ? length(var.services) : 0
  name                               = "${var.name}-${lookup(var.services[count.index], "name", null)}-srv-${var.environment}"
  cluster                            = var.ecs_cluster_id
  task_definition                    = aws_ecs_task_definition.main[count.index].arn
  desired_count                      = var.service_desired_count
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  health_check_grace_period_seconds  = 60
  launch_type                        = "FARGATE"
  scheduling_strategy                = "REPLICA"

  network_configuration {
    security_groups  = var.ecs_service_security_groups
    subnets          = var.subnets.*.id
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main[count.index].arn
    container_name   = "${var.name}-${lookup(var.services[count.index], "name", null)}-container-${var.environment}"
    container_port   = lookup(var.services[count.index], "port", 80)
  }

  # we ignore task_definition changes as the revision changes on deploy
  # of a new version of the application
  # desired_count is ignored as it can change due to autoscaling policy
  lifecycle {
    ignore_changes = [task_definition, desired_count]
  }
}

resource "aws_appautoscaling_target" "ecs_target" {
  count              = length(var.services) > 0 ? length(var.services) : 0
  max_capacity       = 4
  min_capacity       = 1
  resource_id        = "service/${var.ecs_cluster_name}/${aws_ecs_service.main[count.index].name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}


resource "aws_appautoscaling_policy" "ecs_policy_memory" {
  count              = length(var.services) > 0 ? length(var.services) : 0
  name               = "memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[count.index].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[count.index].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[count.index].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value       = 80
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  count              = length(var.services) > 0 ? length(var.services) : 0
  name               = "cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target[count.index].resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target[count.index].scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target[count.index].service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value       = 60
    scale_in_cooldown  = 300
    scale_out_cooldown = 300
  }
}

resource "aws_cloudwatch_log_group" "main" {
  count = length(var.services) > 0 ? length(var.services) : 0
  name  = "/ecs/${var.ecs_cluster_name}/${lookup(var.services[count.index], "name", null)}/${var.name}-task-${var.environment}"

  tags = {
    Name        = "${var.name}-task-${var.environment}"
    Environment = var.environment
  }
}

locals {
  image_urls = [for service in var.services : 
      join(":", [lookup(var.ecr_repository_urls, lookup(service, "name", null)), lookup(service, "version", "latest")])
    ]
}

output "aws_lb_target_group_arn" {
  value = [aws_lb_target_group.main.*.arn]
}

output "aws_cloudwatch_log_group_name" {
  value = [aws_cloudwatch_log_group.main.*.name]
}
