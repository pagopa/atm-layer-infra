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

  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_resource.root_microservice[each.key].id
  http_method          = "ANY"
  authorization        = each.value.authorization ? "COGNITO_USER_POOLS" : "NONE"
  authorizer_id        = each.value.authorization ? aws_api_gateway_authorizer.jwt.id : ""
  authorization_scopes = each.value.authorization ? aws_cognito_resource_server.resource.scope_identifiers : []
  api_key_required     = each.value.api_key_required

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

  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_resource.root_path_proxy[each.key].id
  http_method          = "ANY"
  authorization        = each.value.authorization ? "COGNITO_USER_POOLS" : "NONE"
  authorizer_id        = each.value.authorization ? aws_api_gateway_authorizer.jwt.id : ""
  authorization_scopes = each.value.authorization ? aws_cognito_resource_server.resource.scope_identifiers : []
  api_key_required     = each.value.api_key_required

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
# API Gateway - Authorizer
#########
resource "aws_api_gateway_authorizer" "jwt" {
  name            = "jwt"
  rest_api_id     = aws_api_gateway_rest_api.api.id
  type            = "COGNITO_USER_POOLS"
  identity_source = "method.request.header.Authorization"
  provider_arns   = [aws_cognito_user_pool.userpool.arn]
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

#########
# API Gateway - Stage
#########
resource "aws_api_gateway_stage" "stage" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = var.environment
  deployment_id = aws_api_gateway_deployment.deployment.id
}

resource "aws_api_gateway_method_settings" "settings" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = aws_api_gateway_stage.stage.stage_name
  method_path = "*/*"

  settings {
    metrics_enabled = true
  }
}

#########
# Cognito - User pool
#########
resource "aws_cognito_user_pool" "userpool" {
  name                = "${local.namespace}-userpool"
  username_attributes = ["email"]
  mfa_configuration   = "OFF"
}

resource "aws_cognito_user_pool_client" "client" {
  name = "m2m"

  user_pool_id = aws_cognito_user_pool.userpool.id

  generate_secret              = true
  explicit_auth_flows          = ["ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  allowed_oauth_flows          = ["client_credentials"]
  allowed_oauth_scopes         = aws_cognito_resource_server.resource.scope_identifiers
  supported_identity_providers = ["COGNITO"]

  token_validity_units {
    access_token  = "minutes"
    id_token      = "minutes"
    refresh_token = "days"
  }
}

resource "aws_cognito_user_pool_domain" "domain" {
  domain       = "${local.namespace}-m2m"
  user_pool_id = aws_cognito_user_pool.userpool.id
}

resource "aws_cognito_resource_server" "resource" {
  identifier = "dev"
  name       = "dev"

  scope {
    scope_name        = "tasks"
    scope_description = "tasks"
  }

  user_pool_id = aws_cognito_user_pool.userpool.id
}
