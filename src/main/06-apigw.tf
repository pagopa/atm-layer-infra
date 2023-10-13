locals {
  api_gateway_name = "${local.namespace}-${var.api_gateway_name}"
}

#########
# API Gateway - REST API
#########
resource "aws_api_gateway_rest_api" "api" {
  name        = local.api_gateway_name
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

# # Following resource needs Internal ALB

# #########
# # API Gateway - Internal microservice - quarkus_hello_world
# #########
# resource "aws_api_gateway_resource" "quarkus_hello_world" {
#   rest_api_id = aws_api_gateway_rest_api.api.id
#   parent_id   = aws_api_gateway_rest_api.api.root_resource_id
#   path_part   = var.microservices["quarkus_hello_world"].name
# }

# resource "aws_api_gateway_method" "quarkus_hello_world" {
#   rest_api_id   = aws_api_gateway_rest_api.api.id
#   resource_id   = aws_api_gateway_resource.quarkus_hello_world.id
#   http_method   = "GET"
#   authorization = "NONE"
# }

# resource "aws_api_gateway_integration" "quarkus_hello_world" {
#   rest_api_id             = aws_api_gateway_rest_api.api.id
#   resource_id             = aws_api_gateway_resource.quarkus_hello_world.id
#   http_method             = aws_api_gateway_method.quarkus_hello_world.http_method
#   integration_http_method = "ANY"
#   type                    = "HTTP_PROXY"
#   connection_id           = aws_api_gateway_vpc_link.vpc_link.id
#   connection_type         = "VPC_LINK"
#   uri                     = "http://${aws_lb.nlb_int.dns_name}/${var.microservices["quarkus_hello_world"].name}/"

#   tls_config {
#     insecure_skip_verification = true
#   }
# }

# #########
# # API Gateway - Internal microservice - quarkus_hello_world/{proxy+}
# #########
resource "aws_api_gateway_resource" "quarkus_hello_world_proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "quarkus_hello_world_proxy" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.quarkus_hello_world_proxy.id
  http_method   = "ANY"
  authorization = "NONE"

  request_parameters = {
    "method.request.path.proxy" = true
  }

}

resource "aws_api_gateway_integration" "quarkus_hello_world_proxy" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.quarkus_hello_world_proxy.id
  http_method             = aws_api_gateway_method.quarkus_hello_world_proxy.http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  connection_id           = aws_api_gateway_vpc_link.vpc_link.id
  connection_type         = "VPC_LINK"
  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
  uri = "http://${aws_lb.nlb_int.dns_name}/{proxy}/"

  tls_config {
    insecure_skip_verification = true
  }
}

# #########
# # API Gateway - Deployment
# #########
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  variables = {
    deployed_at = "${timestamp()}"
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.quarkus_hello_world_proxy
  ]
}

resource "aws_api_gateway_stage" "stage" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = var.environment
  deployment_id = aws_api_gateway_deployment.deployment.id
}
