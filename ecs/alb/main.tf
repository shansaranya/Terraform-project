resource "aws_lb" "main" {
  name               = "${var.name}-alb-${var.environment}"
  internal           = false
  load_balancer_type = "application"
  security_groups    = var.alb_security_groups
  subnets            = local.aws_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name        = "${var.name}-alb-${var.environment}"
    Environment = var.environment
  }
}

locals {
  aws_subnet_ids = coalescelist(var.subnets.*.id)
}

output "aws_lb_arn" {
  value = aws_lb.main.arn
}
