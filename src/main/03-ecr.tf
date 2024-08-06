########
# ECR Repository
########
resource "aws_ecr_repository" "microservice" {
  for_each = var.services

  name                 = "${local.namespace}-${each.value.name}"
  image_tag_mutability = "IMMUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_lifecycle_policy" "microservice" {
  for_each = var.services

  repository = aws_ecr_repository.microservice[each.key].name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Expire images older than 1 days if untagged",
            "selection": {
                "tagStatus": "untagged",
                "countType": "sinceImagePushed",
                "countUnit": "days",
                "countNumber": 1
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}
