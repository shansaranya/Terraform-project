variable "name" {
  description = "the name of your stack, e.g. \"demo\""
}

variable "environment" {
  description = "the name of your environment, e.g. \"prod\""
}

variable "region" {
  description = "the AWS region in which resources are created"
  default     = "ap-south-1"
}

variable "subnets" {
  description = "List of subnet IDs"
}

variable "vpc_id" {
  description = "VPC ID"
}

variable "aws_lb_arn" {
  description = "AWS ALB arn"
}

variable "ecs_task_role_arn" {
  description = "ECS task role arn"
}

variable "ecs_task_execution_role_arn" {
  description = "ECS task execution role arn"
}

variable "ecs_service_security_groups" {
  description = "Comma separated list of security groups"
}

variable "ecr_repository_urls" {
  description = "Docker image repo url to be launched"
}

# variable "aws_lb_target_group_arn" {
#   description = "ARN of the alb target group"
# }

variable "service_desired_count" {
  description = "Number of services running in parallel"
}

variable "container_environment" {
  description = "The container environmnent variables"
  type        = list(any)
}

variable "container_secrets" {
  description = "The container secret environmnent variables"
  type        = list(any)
}

# variable "container_secrets_arns" {
#   description = "ARN for secrets"
# }

variable "services" {
  description = "List of services to be deployed in ECS"
  type        = list(any)
}

variable "ecs_cluster_id" {
  description = "ECS cluster id to deploy services"
}

variable "ecs_cluster_name" {
  description = "ECS cluster name to deploy services"
}
