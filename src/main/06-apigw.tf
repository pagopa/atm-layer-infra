#########
# API Gateway - REST API
#########
resource "aws_api_gateway_rest_api" "my_api" {
  name        = "api-name"
  description = "API Gateway"
}

# Following resource needs Internal NLB

#########
# API Gateway - VPC Link for NLB
#########
resource "aws_api_gateway_vpc_link" "vpc_link" {
  name        = "api-gateway-vpc-link-nlb"
  description = "VPC link for my API Gateway"
  target_arns = [aws_lb.nlb_int.arn]
}

# Following resource needs Internal ALB

#########
# API Gateway - Internal microservice - Microservice5
#########
resource "aws_api_gateway_resource" "microservice5" {
  rest_api_id = aws_api_gateway_rest_api.my_api.id
  parent_id   = aws_api_gateway_rest_api.my_api.root_resource_id
  path_part   = var.microservice5
}

resource "aws_api_gateway_method" "microservice5" {
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  resource_id   = aws_api_gateway_resource.microservice5.id
  http_method   = "GET"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "microservice5" {
  rest_api_id             = aws_api_gateway_rest_api.my_api.id
  resource_id             = aws_api_gateway_resource.microservice5.id
  http_method             = aws_api_gateway_method.microservice5.http_method
  integration_http_method = "GET"
  type                    = "HTTP_PROXY"
  connection_id           = aws_api_gateway_vpc_link.vpc_link.id
  connection_type         = "VPC_LINK"
  uri                     = "http://${aws_lb.nlb_int.dns_name}/${var.microservice5}/"

  tls_config {
    insecure_skip_verification = true
  }
}

#########
# API Gateway - Deployment
#########
resource "aws_api_gateway_deployment" "deployment" {
  depends_on = [
    # aws_api_gateway_integration.microservice2,
    aws_api_gateway_integration.microservice5,
  ]

  rest_api_id = aws_api_gateway_rest_api.my_api.id

  stage_description = md5(jsonencode(aws_api_gateway_rest_api.my_api.body))
  triggers = {
    redeployment = sha1(
      join(",", [
        jsonencode(aws_api_gateway_rest_api.my_api.body),
      ])
    )
    version = 1
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "stage" {
  rest_api_id   = aws_api_gateway_rest_api.my_api.id
  stage_name    = var.environment
  deployment_id = aws_api_gateway_deployment.deployment.id
}
