locals {
  dashboard_name          = "${local.namespace}-dashboard"
  lambda_s3_function_name = "${local.namespace}-${var.lambda_s3_function_name}"
}

########
# Cloudwatch - Dashboard
########
resource "aws_cloudwatch_dashboard" "overview" {
  dashboard_name = "${local.dashboard_name}-overview"

  dashboard_body = <<EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/ApiGateway", "5XXError", 
          "ApiName", "${local.api_gateway_name}", 
          "Stage", "${var.environment}", 
          { "stat": "Sum" }]
        ],
        "period": 300,
        "region": "${var.aws_region}",
        "title": "API Gateway 5XX Requests"
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/ApiGateway", "4XXError", 
          "ApiName", "${local.api_gateway_name}", 
          "Stage", "${var.environment}", 
          { "stat": "Sum" }]
        ],
        "period": 300,
        "region": "${var.aws_region}",
        "title": "API Gateway 4XX Requests"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", 
          "${aws_eks_node_group.eks_node_group.resources[0].autoscaling_groups[0].name}", 
          { "stat": "Average"}]
        ],
        "period": 300,
        "region": "${var.aws_region}",
        "title": "EKS Nodes CPU Utilizations"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 12,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/EC2", "NetworkIn", "AutoScalingGroupName", 
          "${aws_eks_node_group.eks_node_group.resources[0].autoscaling_groups[0].name}", 
          { "stat": "Sum"}],
          ["AWS/EC2", "NetworkOut", "AutoScalingGroupName", 
          "${aws_eks_node_group.eks_node_group.resources[0].autoscaling_groups[0].name}", 
          { "stat": "Sum"}]
        ],
        "period": 300,
        "region": "${var.aws_region}",
        "title": "EKS Nodes Network Traffic"
      }
    }
  ]
}
EOF

  depends_on = [aws_api_gateway_rest_api.api, aws_eks_node_group.eks_node_group]
}

resource "aws_cloudwatch_dashboard" "api_details" {
  for_each = var.api_gateway_integrations

  dashboard_name = "${local.dashboard_name}-${each.value.api_path}-api-details"

  dashboard_body = <<EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/ApiGateway", "5XXError", 
            "ApiName", "${local.api_gateway_name}", 
            "Method", "GET", 
            "Resource", "/api/v1/${each.value.api_path}/{proxy+}", 
            "Stage", "${var.environment}", 
            { "stat": "Sum" }],
          ["AWS/ApiGateway", "4XXError", 
            "ApiName", "${local.api_gateway_name}", 
            "Method", "GET", 
            "Resource", "/api/v1/${each.value.api_path}/{proxy+}", 
            "Stage", "${var.environment}", 
            { "stat": "Sum" }]
        ],
        "period": 300,
        "region": "${var.aws_region}",
        "title": "GET ${each.value.api_path}/ API Error"
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/ApiGateway", "5XXError", 
            "ApiName", "${local.api_gateway_name}", 
            "Method", "POST", 
            "Resource", "/api/v1/${each.value.api_path}/{proxy+}", 
            "Stage", "${var.environment}", 
            { "stat": "Sum" }],
          ["AWS/ApiGateway", "4XXError", 
            "ApiName", "${local.api_gateway_name}", 
            "Method", "POST", 
            "Resource", "/api/v1/${each.value.api_path}/{proxy+}", 
            "Stage", "${var.environment}", 
            { "stat": "Sum" }]
        ],
        "period": 300,
        "region": "${var.aws_region}",
        "title": "POST ${each.value.api_path}/ API Error"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 6,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/ApiGateway", "5XXError", 
            "ApiName", "${local.api_gateway_name}", 
            "Method", "PUT", 
            "Resource", "/api/v1/${each.value.api_path}/{proxy+}", 
            "Stage", "${var.environment}", 
            { "stat": "Sum" }],
          ["AWS/ApiGateway", "4XXError", 
            "ApiName", "${local.api_gateway_name}", 
            "Method", "PUT", 
            "Resource", "/api/v1/${each.value.api_path}/{proxy+}", 
            "Stage", "${var.environment}", 
            { "stat": "Sum" }]
        ],
        "period": 300,
        "region": "${var.aws_region}",
        "title": "PUT ${each.value.api_path}/ API Error"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 12,
      "width": 12,
      "height": 6,
      "properties": {
        "view": "singleValue",
        "sparkline": false,
        "metrics": [
          ["AWS/ApiGateway", "Latency", 
            "ApiName", "${local.api_gateway_name}", 
            "Method", "GET", 
            "Resource", "/api/v1/${each.value.api_path}/{proxy+}", 
            "Stage", "${var.environment}", 
            { "stat": "Average", "period": 300 }],
          ["AWS/ApiGateway", "Latency", 
            "ApiName", "${local.api_gateway_name}", 
            "Method", "POST", 
            "Resource", "/api/v1/${each.value.api_path}/{proxy+}", 
            "Stage", "${var.environment}", 
            { "stat": "Average", "period": 300 }],
          ["AWS/ApiGateway", "Latency", 
            "ApiName", "${local.api_gateway_name}", 
            "Method", "PUT", 
            "Resource", "/api/v1/${each.value.api_path}/{proxy+}", 
            "Stage", "${var.environment}", 
            { "stat": "Average", "period": 300 }]
        ],
        "region": "${var.aws_region}",
        "title": "${each.value.api_path}/ API Latency"
      }
    }
  ]
}
EOF

  depends_on = [aws_api_gateway_rest_api.api, aws_eks_node_group.eks_node_group]
}

########
# Cloudwatch - Eventbridge + Lambda for log export
########
resource "aws_iam_role" "lambda_s3_role" {
  name = "ExportCWLogs-Lambda-Role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy" "lambda_s3_policy" {
  name = "lambda_export_s3_policy"
  role = aws_iam_role.lambda_s3_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:*"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_lambda_s3_basic_execution" {
  role       = aws_iam_role.lambda_s3_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "s3_log_export" {
  function_name = local.lambda_s3_function_name
  role          = aws_iam_role.lambda_s3_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = var.lambda_function_runtime
  filename      = "lambdas/${var.environment}/s3_log_export/lambda_function_payload.zip"

  environment {
    variables = {
      DESTINATION_BUCKET = aws_s3_bucket.s3_backup_logs.id,
      LOG_GROUP          = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.api.id}/${var.environment}"
    }
  }
}

resource "aws_cloudwatch_event_rule" "s3_log_export" {
  name                = "${local.namespace}-start-cw-s3-log-export"
  schedule_expression = var.cloudwatch_rule_log_export
}

resource "aws_cloudwatch_event_target" "s3_log_export" {
  rule      = aws_cloudwatch_event_rule.s3_log_export.name
  target_id = "start-cw-s3-log-export"
  arn       = aws_lambda_function.s3_log_export.arn
}

resource "aws_lambda_permission" "allow_s3_log_export" {
  statement_id  = "AllowExecutionFromCloudWatchStartLogExport"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.s3_log_export.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.s3_log_export.arn
}
