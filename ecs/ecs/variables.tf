variable "name" {
  description = "the name of your stack, e.g. \"demo\""
}

variable "environment" {
  description = "the name of your environment, e.g. \"prod\""
}

variable "container_secrets_arns" {
  description = "ARN for secrets"
}

variable "s3_bucket_name" {
  description = "S3 bucket to store documents"
}