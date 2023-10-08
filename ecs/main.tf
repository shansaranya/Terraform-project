provider "aws" {
  shared_credentials_files = ["$HOME/.aws/credentials"]
  shared_config_files      = ["$HOME/.aws/config"]
  profile                  = "default"
  region                   = var.aws-region
}

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }

  # backend "s3" {
  #   bucket  = "terraform-backend-store"
  #   encrypt = true
  #   key     = "terraform.tfstate"
  #   region  = "eu-central-1"
  #   # dynamodb_table = "terraform-state-lock-dynamo" - uncomment this line once the terraform-state-lock-dynamo has been terraformed
  # }
}

# resource "aws_dynamodb_table" "dynamodb-terraform-state-lock" {
#   name           = "terraform-state-lock-dynamo"
#   hash_key       = "LockID"
#   read_capacity  = 20
#   write_capacity = 20
#   attribute {
#     name = "LockID"
#     type = "S"
#   }
#   tags = {
#     Name = "DynamoDB Terraform State Lock Table"
#   } 
# }


module "vpc" {
  source             = "./vpc"
  name               = var.name
  cidr               = var.cidr
  private_subnets    = var.private_subnets
  public_subnets     = var.public_subnets
  availability_zones = var.availability_zones
  environment        = var.environment
}

module "security_groups" {
  source      = "./security-groups"
  name        = var.name
  vpc_id      = module.vpc.id
  environment = var.environment
  services    = local.apps
}

module "alb" {
  source              = "./alb"
  name                = var.name
  vpc_id              = module.vpc.id
  subnets             = module.vpc.public_subnets
  environment         = var.environment
  alb_security_groups = [module.security_groups.alb]
  # alb_tls_cert_arn    = var.tsl_certificate_arn
}

module "ecr" {
  source      = "./ecr"
  name        = var.name
  environment = var.environment
  services    = local.apps
}

module "secrets" {
  source              = "./secrets"
  name                = var.name
  environment         = var.environment
  application_secrets = var.application_secrets
}

module "ecs" {
  source                 = "./ecs"
  name                   = var.name
  environment            = var.environment
  s3_bucket_name         = var.s3_bucket_name
  container_secrets_arns = module.secrets.application_secrets_arn
}

module "services" {
  source                      = "./service"
  name                        = var.name
  environment                 = var.environment
  region                      = var.region
  vpc_id                      = module.vpc.id
  aws_lb_arn                  = module.alb.aws_lb_arn
  subnets                     = var.environment == "prod" ? module.vpc.private_subnets : module.vpc.public_subnets
  ecs_cluster_id              = module.ecs.ecs_cluster_id
  ecs_cluster_name            = module.ecs.ecs_cluster_name
  services                    = local.apps
  ecs_service_security_groups = module.security_groups.ecs_tasks
  ecs_task_role_arn           = module.ecs.ecs_task_role_arn
  ecs_task_execution_role_arn = module.ecs.ecs_task_execution_role_arn
  service_desired_count       = var.service_desired_count
  ecr_repository_urls         = module.ecr.aws_ecr_repository_urls
  container_environment = [
    { name = "LOG_LEVEL", value = "DEBUG" },
    { name = "PORT", value = "8080" }
  ]
  container_secrets      = module.secrets.secrets_map
  # container_secrets_arns = module.secrets.application_secrets_arn
}


# Listing apps to deploy
locals {
  apps = [
    {
      name : "frontend",
      version : "latest",
      port : 80,
      context : "/",
      health : "/",
      deploy : true,
      replica : 1
      cpu : 256,
      memory : 512,
      priority : 100
    },
    {
      name : "document-service",
      version : "latest",
      port : 80,
      context : "/document-service/",
      health : "/document-service/api/actuator/health",
      deploy : true,
      replica : 1
      cpu : 256,
      memory : 512,
      priority : 90
    },
    {
      name : "user-service",
      version : "latest",
      port : 80,
      context : "/user-service/",
      health : "/user-service/api/actuator/health",
      deploy : true,
      replica : 1
      cpu : 256,
      memory : 512,
      priority : 80
    }
  ]
}
