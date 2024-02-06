locals {
  api_gateway_name = "${local.namespace}-${var.api_gateway_name}"
  user_pools = {
    "jwt"            = "${aws_cognito_user_pool.userpool.arn}"
    "jwt-backoffice" = "${aws_cognito_user_pool.userpool_backoffice.arn}"
  }
  api_scopes = {
    "task"       = aws_cognito_resource_server.resource.scope_identifiers
    "backoffice" = []
  }
}

#########
# API Gateway - REST API
#########
resource "aws_api_gateway_rest_api" "api" {
  name        = local.api_gateway_name
  description = "API Gateway"

  binary_media_types = ["multipart/form-data"]

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

#########
# API Gateway - IAM Role for logs
#########
resource "aws_api_gateway_account" "api_log" {
  cloudwatch_role_arn = aws_iam_role.api_log.arn
}

resource "aws_iam_role" "api_log" {
  name                = "apigw-logs"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "api_log" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonAPIGatewayPushToCloudWatchLogs"
  role       = aws_iam_role.api_log.name
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
  for_each = { for k, v in var.api_gateway_integrations : k => v if v.api_enabled }

  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.root_v1.id
  path_part   = each.value.api_path
}

resource "aws_api_gateway_method" "root_microservice_any_proxy" {
  for_each = { for k, v in var.api_gateway_integrations : k => v if v.api_enabled && contains(v.methods_allowed, "ANY") }

  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_resource.root_microservice[each.key].id
  http_method          = "ANY"
  authorization        = each.value.authorization ? "COGNITO_USER_POOLS" : "NONE"
  authorizer_id        = each.value.authorization ? aws_api_gateway_authorizer.jwt[each.value.authorizer].id : ""
  authorization_scopes = each.value.authorization ? local.api_scopes[each.value.authorizer] : []
  api_key_required     = each.value.api_key_required

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "root_microservice_integration_proxy" {
  for_each = { for k, v in var.api_gateway_integrations : k => v if v.api_enabled && contains(v.methods_allowed, "ANY") }

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
  for_each = { for k, v in var.api_gateway_integrations : k => v if v.api_enabled }

  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.root_microservice[each.key].id
  path_part   = "{proxy+}"
}

#########
# API Gateway - {proxy+} METHOD GET for microservice/{proxy+}
########
resource "aws_api_gateway_method" "root_path_proxy_method_request_get" {
  for_each = { for k, v in var.api_gateway_integrations : k => v if v.api_enabled && contains(v.methods_allowed, "GET") }

  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_resource.root_path_proxy[each.key].id
  http_method          = "GET"
  authorization        = each.value.authorization ? "COGNITO_USER_POOLS" : "NONE"
  authorizer_id        = each.value.authorization ? aws_api_gateway_authorizer.jwt[each.value.authorizer].id : ""
  authorization_scopes = each.value.authorization ? local.api_scopes[each.value.authorizer] : []
  api_key_required     = each.value.api_key_required

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "root_path_proxy_integration_request_get" {
  for_each = { for k, v in var.api_gateway_integrations : k => v if v.api_enabled && contains(v.methods_allowed, "GET") }

  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.root_path_proxy[each.key].id
  http_method             = aws_api_gateway_method.root_path_proxy_method_request_get[each.key].http_method
  integration_http_method = "GET"
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
# API Gateway - {proxy+} METHOD POST for microservice/{proxy+}
########
resource "aws_api_gateway_method" "root_path_proxy_method_request_post" {
  for_each = { for k, v in var.api_gateway_integrations : k => v if v.api_enabled && contains(v.methods_allowed, "POST") }

  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_resource.root_path_proxy[each.key].id
  http_method          = "POST"
  authorization        = each.value.authorization ? "COGNITO_USER_POOLS" : "NONE"
  authorizer_id        = each.value.authorization ? aws_api_gateway_authorizer.jwt[each.value.authorizer].id : ""
  authorization_scopes = each.value.authorization ? local.api_scopes[each.value.authorizer] : []
  api_key_required     = each.value.api_key_required

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "root_path_proxy_integration_request_post" {
  for_each = { for k, v in var.api_gateway_integrations : k => v if v.api_enabled && contains(v.methods_allowed, "POST") }

  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.root_path_proxy[each.key].id
  http_method             = aws_api_gateway_method.root_path_proxy_method_request_post[each.key].http_method
  integration_http_method = "POST"
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
# API Gateway - {proxy+} METHOD PUT for microservice/{proxy+}
########
resource "aws_api_gateway_method" "root_path_proxy_method_request_put" {
  for_each = { for k, v in var.api_gateway_integrations : k => v if v.api_enabled && contains(v.methods_allowed, "PUT") }

  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_resource.root_path_proxy[each.key].id
  http_method          = "PUT"
  authorization        = each.value.authorization ? "COGNITO_USER_POOLS" : "NONE"
  authorizer_id        = each.value.authorization ? aws_api_gateway_authorizer.jwt[each.value.authorizer].id : ""
  authorization_scopes = each.value.authorization ? local.api_scopes[each.value.authorizer] : []
  api_key_required     = each.value.api_key_required

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "root_path_proxy_integration_request_put" {
  for_each = { for k, v in var.api_gateway_integrations : k => v if v.api_enabled && contains(v.methods_allowed, "PUT") }

  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.root_path_proxy[each.key].id
  http_method             = aws_api_gateway_method.root_path_proxy_method_request_put[each.key].http_method
  integration_http_method = "PUT"
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
# API Gateway - {proxy+} METHOD DELETE for microservice/{proxy+}
########
resource "aws_api_gateway_method" "root_path_proxy_method_request_delete" {
  for_each = { for k, v in var.api_gateway_integrations : k => v if v.api_enabled && contains(v.methods_allowed, "DELETE") }

  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_resource.root_path_proxy[each.key].id
  http_method          = "DELETE"
  authorization        = each.value.authorization ? "COGNITO_USER_POOLS" : "NONE"
  authorizer_id        = each.value.authorization ? aws_api_gateway_authorizer.jwt[each.value.authorizer].id : ""
  authorization_scopes = each.value.authorization ? local.api_scopes[each.value.authorizer] : []
  api_key_required     = each.value.api_key_required

  request_parameters = {
    "method.request.path.proxy" = true
  }
}

resource "aws_api_gateway_integration" "root_path_proxy_integration_request_delete" {
  for_each = { for k, v in var.api_gateway_integrations : k => v if v.api_enabled && contains(v.methods_allowed, "DELETE") }

  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.root_path_proxy[each.key].id
  http_method             = aws_api_gateway_method.root_path_proxy_method_request_delete[each.key].http_method
  integration_http_method = "DELETE"
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
# API Gateway - {proxy+} METHOD OPTIONS for microservice/{proxy+}
########
resource "aws_api_gateway_method" "root_path_proxy_method_request_options" {
  for_each = { for k, v in var.api_gateway_integrations : k => v if v.api_enabled && contains(v.methods_allowed, "OPTIONS") }

  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_resource.root_path_proxy[each.key].id
  http_method          = "OPTIONS"
  authorization        = "NONE"
  authorizer_id        = ""
  authorization_scopes = []
  api_key_required     = false
}

resource "aws_api_gateway_method_response" "root_path_proxy_method_response_options" {
  for_each = { for k, v in var.api_gateway_integrations : k => v if v.api_enabled && contains(v.methods_allowed, "OPTIONS") }

  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.root_path_proxy[each.key].id
  http_method = aws_api_gateway_method.root_path_proxy_method_request_options[each.key].http_method
  status_code = 200

  response_models = {
    "application/json"                = "Empty"
    "application/json; charset=UTF-8" = "Empty"
    "multipart/form-data"             = "Empty"
  }

  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
}

resource "aws_api_gateway_integration" "root_path_proxy_integration_request_options" {
  for_each = { for k, v in var.api_gateway_integrations : k => v if v.api_enabled && contains(v.methods_allowed, "OPTIONS") }

  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_resource.root_path_proxy[each.key].id
  http_method          = aws_api_gateway_method.root_path_proxy_method_request_options[each.key].http_method
  type                 = "MOCK"
  cache_key_parameters = []
  passthrough_behavior = "WHEN_NO_MATCH"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
    "application/json; charset=UTF-8" = jsonencode({
      statusCode = 200
    })
    "multipart/form-data" = jsonencode({
      statusCode = 200
    })
  }
}

resource "aws_api_gateway_integration_response" "root_path_proxy_integration_response_options" {
  for_each = { for k, v in var.api_gateway_integrations : k => v if v.api_enabled && contains(v.methods_allowed, "OPTIONS") }

  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.root_path_proxy[each.key].id
  http_method = aws_api_gateway_method.root_path_proxy_method_request_options[each.key].http_method
  status_code = aws_api_gateway_method_response.root_path_proxy_method_response_options[each.key].status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'*'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT,DELETE'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }

  response_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
    "application/json; charset=UTF-8" = jsonencode({
      statusCode = 200
    })
    "multipart/form-data" = jsonencode({
      statusCode = 200
    })
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
  for_each = var.api_gateway_authorizers

  name            = each.value.name
  rest_api_id     = aws_api_gateway_rest_api.api.id
  type            = "COGNITO_USER_POOLS"
  identity_source = "method.request.header.Authorization"
  provider_arns   = [lookup(local.user_pools, each.value.user_pool, local.user_pools["jwt"])]
}

#########
# API Gateway - Deployment
#########
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id

  lifecycle {
    create_before_destroy = true
  }

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.root_microservice,
      aws_api_gateway_resource.root_path_proxy,

      aws_api_gateway_method.root_microservice_any_proxy,
      aws_api_gateway_method.root_path_proxy_method_request_get,
      aws_api_gateway_method.root_path_proxy_method_request_post,
      aws_api_gateway_method.root_path_proxy_method_request_put,
      aws_api_gateway_method.root_path_proxy_method_request_delete,
      aws_api_gateway_method.root_path_proxy_method_request_options,

      aws_api_gateway_integration.root_microservice_integration_proxy,
      aws_api_gateway_integration.root_path_proxy_integration_request_get,
      aws_api_gateway_integration.root_path_proxy_integration_request_post,
      aws_api_gateway_integration.root_path_proxy_integration_request_put,
      aws_api_gateway_integration.root_path_proxy_integration_request_delete,
      aws_api_gateway_integration.root_path_proxy_integration_request_options,
      aws_api_gateway_integration_response.root_path_proxy_integration_response_options
    ]))
  }
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
    logging_level   = "INFO"
  }

  depends_on = [ aws_api_gateway_account.api_log ]
}

#########
# Cognito - User pool - M2M
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

  refresh_token_validity = 4
  access_token_validity  = 1
  id_token_validity      = 1
}

resource "aws_cognito_user_pool_domain" "domain" {
  domain       = "${local.namespace}-m2m"
  user_pool_id = aws_cognito_user_pool.userpool.id
}

resource "aws_cognito_resource_server" "resource" {
  identifier = var.environment
  name       = var.environment

  scope {
    scope_name        = "tasks"
    scope_description = "tasks"
  }

  user_pool_id = aws_cognito_user_pool.userpool.id
}

#########
# Cognito - User pool - Backoffice
#########
resource "aws_cognito_user_pool" "userpool_backoffice" {
  name                = "${local.namespace}-backoffice-userpool"
  username_attributes = ["email"]
  mfa_configuration   = "OFF"
}

resource "aws_cognito_identity_provider" "google" {
  attribute_mapping = {
    email    = "email"
    username = "sub"
  }
  idp_identifiers = []
  provider_details = {
    attributes_url                = var.cognito_google_attributes_url
    attributes_url_add_attributes = "true"
    authorize_scopes              = "profile email openid"
    authorize_url                 = var.cognito_google_authorize_url
    client_id                     = var.cognito_google_idp_client_id
    client_secret                 = var.cognito_google_idp_client_secret
    oidc_issuer                   = var.cognito_google_oidc_issuer
    token_request_method          = "POST"
    token_url                     = var.cognito_google_token_url
  }
  provider_name = "Google"
  provider_type = "Google"
  user_pool_id  = aws_cognito_user_pool.userpool_backoffice.id
}

resource "aws_cognito_user_pool_client" "client_backoffice" {
  name = "backoffice"

  user_pool_id = aws_cognito_user_pool.userpool_backoffice.id

  allowed_oauth_flows = ["implicit"]
  allowed_oauth_scopes = [
    "email", "openid", "profile"
  ]

  callback_urls = [
    "https://${local.namespace}-backoffice.auth.${var.aws_region}.amazoncognito.com",
    "https://${local.namespace}-backoffice.auth.${var.aws_region}.amazoncognito.com/oauth2/idpresponse",
    "https://${aws_cloudfront_distribution.s3_webconsole_distribution.domain_name}/webconsole/login/callback"
  ]

  refresh_token_validity = 30
  access_token_validity  = 1
  id_token_validity      = 1

  token_validity_units {
    access_token  = "days"
    id_token      = "days"
    refresh_token = "days"
  }
}

resource "aws_cognito_user_pool_domain" "domain_backoffice" {
  domain       = "${local.namespace}-backoffice"
  user_pool_id = aws_cognito_user_pool.userpool_backoffice.id
}
