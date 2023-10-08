# This file creates secrets in the AWS System Manager/Parameter store
# Note that this does not contain any actual secret values
# make sure to not commit any secret values to git!
# you could put them in secrets.tfvars which is in .gitignore


# resource "aws_secretsmanager_secret" "application_secrets" {
#   count = length(var.application_secrets)
#   name  = "${var.name}-application_secrets-${var.environment}-${element(keys(var.application_secrets), count.index)}"
# }


# resource "aws_secretsmanager_secret_version" "application_secrets_values" {
#   count         = length(var.application_secrets)
#   secret_id     = element(aws_secretsmanager_secret.application_secrets.*.id, count.index)
#   secret_string = element(values(var.application_secrets), count.index)
# }

resource "aws_ssm_parameter" "application_secrets" {
  count       = length(var.application_secrets)
  name        = "/${var.name}/${var.environment}/${element(keys(var.application_secrets), count.index)}"
  description = "Secret string for ${element(keys(var.application_secrets), count.index)}"
  type        = "SecureString"
  value       = element(values(var.application_secrets), count.index)

  tags = {
    Name        = "${var.name}-cluster-${var.environment}"
    Environment = var.environment
  }
}

locals {
  secrets = zipmap(keys(var.application_secrets), aws_ssm_parameter.application_secrets.*.arn)

  secretMap = [for secretKey in keys(var.application_secrets) : {
    name      = secretKey
    valueFrom = lookup(local.secrets, secretKey)
    }
  ]
}

output "application_secrets_arn" {
  value = aws_ssm_parameter.application_secrets.*.arn
}

output "secrets_map" {
  value = local.secretMap
}

