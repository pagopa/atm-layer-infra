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

#########
# API Gateway - root resource path api/
#########
resource "aws_api_gateway_resource" "root_api" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "api"
}

#########
# API Gateway - root resource path v1/
#########
resource "aws_api_gateway_resource" "root_v1" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.root_api.id
  path_part   = "v1"
}

#########
# API Gateway - root resource path for microservice/
#########
resource "aws_api_gateway_resource" "root_microservice" {
  for_each = { for k, v in var.services : k => v if v.api_enabled }

  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.root_v1.id
  path_part   = each.value.api_path
}

resource "aws_api_gateway_method" "root_microservice_any_proxy" {
  for_each = { for k, v in var.services : k => v if v.api_enabled }

  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_resource.root_microservice[each.key].id
  http_method      = "ANY"
  authorization    = "NONE"
  api_key_required = each.value.api_key_required

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "root_microservice_integration_proxy" {
  for_each = { for k, v in var.services : k => v if v.api_enabled }

  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.root_microservice[each.key].id
  http_method             = aws_api_gateway_method.root_microservice_any_proxy[each.key].http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  connection_id           = aws_api_gateway_vpc_link.vpc_link.id
  connection_type         = "VPC_LINK"
  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
  uri = "http://${aws_lb.nlb_int.dns_name}/${each.value.api_uri}"

  tls_config {
    insecure_skip_verification = true
  }
}

#########
# API Gateway - {proxy+} path for microservice/{proxy+}
#########
resource "aws_api_gateway_resource" "root_path_proxy" {
  for_each = { for k, v in var.services : k => v if v.api_enabled }

  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.root_microservice[each.key].id
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "root_path_any_proxy" {
  for_each = { for k, v in var.services : k => v if v.api_enabled }

  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_resource.root_path_proxy[each.key].id
  http_method      = "ANY"
  authorization    = "NONE"
  api_key_required = each.value.api_key_required

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "root_path_integration_proxy" {
  for_each = { for k, v in var.services : k => v if v.api_enabled }

  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.root_path_proxy[each.key].id
  http_method             = aws_api_gateway_method.root_path_any_proxy[each.key].http_method
  integration_http_method = "ANY"
  type                    = "HTTP_PROXY"
  connection_id           = aws_api_gateway_vpc_link.vpc_link.id
  connection_type         = "VPC_LINK"
  request_parameters = {
    "integration.request.path.proxy" = "method.request.path.proxy"
  }
  uri = "http://${aws_lb.nlb_int.dns_name}/${each.value.api_uri}"

  tls_config {
    insecure_skip_verification = true
  }
}

#########
# API Gateway - API Key
#########
resource "aws_api_gateway_api_key" "api_key" {
  name    = "${local.namespace}-api-key"
  enabled = var.api_gateway_key_enabled
}

resource "aws_api_gateway_usage_plan" "api_usage_plan" {
  name        = "api_usage_plan"
  description = "Usage plan for my APIs"

  api_stages {
    api_id = aws_api_gateway_rest_api.api.id
    stage  = aws_api_gateway_stage.stage.stage_name
  }
}

resource "aws_api_gateway_usage_plan_key" "api_usage_plan_key" {
  key_id        = aws_api_gateway_api_key.api_key.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.api_usage_plan.id
}

#########
# API Gateway - Deployment
#########
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  variables = {
    deployed_at = "${timestamp()}"
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.root_path_integration_proxy
  ]
}

resource "aws_api_gateway_stage" "stage" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = var.environment
  deployment_id = aws_api_gateway_deployment.deployment.id
}
