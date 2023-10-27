########
# ECR Repository
########
resource "aws_ecr_repository" "microservice" {
  for_each = var.services

  name                 = "${local.namespace}-${each.value.name}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
