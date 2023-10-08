resource "aws_ecr_repository" "main" {
  count                = length(var.services)
  name                 = lookup(var.services[count.index], "name", null)
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name        = "${var.name}-ecr-${var.environment}"
    Environment = var.environment
  }
}

data "aws_ecr_repository" "main" {
  count = length(var.services) > 0 ? length(var.services) : 0
  name  = lookup(var.services[count.index], "name", null)
  depends_on = [ aws_ecr_repository.main ]
}

resource "aws_ecr_lifecycle_policy" "main" {
  #for_each = { for repos in var.app_ecr_repo : join("-", [repos.name]) => repos }
  #repository = aws_ecr_repository.main.name

  count      = length(var.services) > 0 ? length(var.services) : 0
  repository = data.aws_ecr_repository.main[count.index].name

  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "keep last 10 images"
      action = {
        type = "expire"
      }
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 10
      }
    }]
  })
  depends_on = [ data.aws_ecr_repository.main ]
}

output "aws_ecr_repository_urls" {
  value = zipmap(data.aws_ecr_repository.main.*.name, data.aws_ecr_repository.main.*.repository_url)
}

output "aws_ecr_repository_names" {
  description = "ECR repository name."
  value       = [data.aws_ecr_repository.main.*.name]
}
