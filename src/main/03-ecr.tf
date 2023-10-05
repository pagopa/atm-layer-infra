########
# ECR Repository
########
resource "aws_ecr_repository" "microservice5" {
  name                 = var.microservice5
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}
