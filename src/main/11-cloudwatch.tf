locals {
  dashboard_name               = "${local.namespace}-dashboard"
  lambda_s3_function_name      = "${local.namespace}-${var.lambda_s3_function_name}"
  lambda_latency_function_name = "latency-logging"
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
      "height": 6,
      "width": 24,
      "y": 0,
      "x": 0,
      "properties": {
        "metrics": [
          ["AWS/ApiGateway", "5XXError", "ApiName", "${local.api_gateway_name}", "Stage", "${var.environment}", { "stat": "Sum" }],
          [".", "4XXError", ".", ".", ".", ".", { "stat": "Sum" }]
        ],
        "period": 300,
        "region": "${var.aws_region}",
        "title": "API Gateway 4XX & 5XX Requests"
      }
    },
    {
      "type": "metric",
      "height": 6,
      "width": 12,
      "y": 6,
      "x": 0,
      "properties": {
        "metrics": [
          ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", 
          "${aws_eks_node_group.eks_node_group.resources[0].autoscaling_groups[0].name}", 
          { "stat": "Average"}]
        ],
        "period": 300,
        "region": "${var.aws_region}",
        "title": "EKS Nodes CPU Utilization"
      }
    },
    {
      "type": "metric",
      "height": 6,
      "width": 12,
      "y": 6,
      "x": 12,
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
    },
    {
      "type": "metric",
      "x": 0,
      "y": 12,
      "width": 12,
      "height": 6,
      "properties": {
        "view": "timeSeries",
        "stacked": false,
        "metrics": [
            [ "AWS/RDS", "CPUUtilization", "DBClusterIdentifier", "${aws_rds_cluster.rds.id}", { "period": 60 } ]
        ],
        "region": "${var.aws_region}",
        "title": "RDS Instances CPU Utilization"
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
            [ "AWS/RDS", "DatabaseConnections", "DBClusterIdentifier", "${aws_rds_cluster.rds.id}", { "period": 60 } ]
        ],
        "view": "timeSeries",
        "stacked": false,
        "region": "${var.aws_region}",
        "title": "RDS Instances DB Connections",
        "period": 300
      }
    }
  ]
}
EOF

  depends_on = [aws_api_gateway_rest_api.api, aws_eks_node_group.eks_node_group]
}

resource "aws_cloudwatch_dashboard" "availability" {
  dashboard_name = "${local.dashboard_name}-availability"

  dashboard_body = jsonencode({
    widgets = [
      {
        height = 4
        width  = 10
        y      = 0
        x      = 0
        type   = "log"
        properties = {
          query   = "SOURCE '${local.api_gateway_custom_log_group}' ${var.cloudwatch_dashboard_availability_query}"
          region  = "${var.aws_region}"
          stacked = false
          title   = "Log group: ${local.api_gateway_custom_log_group}"
          view    = "table"
        }
      }
    ]
  })
}

resource "aws_cloudwatch_dashboard" "latency" {
  dashboard_name = "${local.dashboard_name}-latency"

  dashboard_body = <<EOF
{
    "widgets": [
        {
            "height": 4,
            "width": 15,
            "y": 0,
            "x": 0,
            "type": "log",
            "properties": {
                "query": "SOURCE '/aws/lambda/latency-logging' | fields @timestamp, @message\n| filter @message like /Latency Internal.*?\\[ms\\] = (\\d+)/ or @message like /Latency External.*?\\[ms\\] = (\\d+)/\n| parse @message /Latency Internal.*?\\[ms\\] = (?<internal_latency>\\d+)/\n| parse @message /Latency External.*?\\[ms\\] = (?<external_latency>\\d+)/\n| stats \n    round(avg(internal_latency), 2) as avg_internal_latency, \n    round(avg(external_latency), 2) as avg_external_latency,\n    round(if((avg(internal_latency) - 250) < 0, 0, ((avg(internal_latency) - 250) / 250) * 100 - 0.10), 2) as percent_internal_latency_exceeding,\n    round(if((avg(external_latency) - 5000) < 0, 0, ((avg(external_latency) - 5000) / 5000) * 100 - 0.10), 2) as percent_external_latency_exceeding\n",
                "region": "${var.aws_region}",
                "stacked": false,
                "title": "Indicatori di monitoraggio latenza",
                "view": "table"
            }
        }
    ]
}
EOF
}

########
# Cloudwatch - Eventbridge + Lambda for monitoring availability
########
resource "aws_iam_role" "lambda_monitoring_role" {
  name = "Monitoring-Lambda-Role"

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

resource "aws_iam_role_policy" "lambda_monitoring_policy" {
  name = "lambda_monitoring_policy"
  role = aws_iam_role.lambda_monitoring_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "logs:*",
          "sns:*",
        ],
        Effect   = "Allow",
        Resource = "*"
        }, {
        Action = [
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem",
          "dynamodb:ConditionCheckItem",
          "dynamodb:PutItem",
          "dynamodb:DescribeTable",
          "dynamodb:DeleteItem",
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query",
          "dynamodb:UpdateItem"
        ],
        Effect = "Allow",
        Resource = [
          "${aws_dynamodb_table.monitoring.arn}"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_lambda_monitoring_basic_execution" {
  role       = aws_iam_role.lambda_monitoring_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "monitoring_availability" {
  function_name = "${local.namespace}-monitoring-availability"
  role          = aws_iam_role.lambda_monitoring_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = var.lambda_function_runtime
  filename      = "lambdas/${var.environment}/monitoring_availability/lambda_function_payload.zip"

  environment {
    variables = {
      LOG_GROUP                         = local.api_gateway_custom_log_group
      NAMESPACE                         = local.namespace
      ENV                               = upper(var.environment)
      MONITORING_ALERT_TOPIC_ARN        = aws_sns_topic.monitoring_alert.arn
      MONITORING_NOTIFICATION_TOPIC_ARN = aws_sns_topic.monitoring_notification.arn
    }
  }
}

resource "aws_cloudwatch_event_rule" "monitoring_availability" {
  name                = "${local.namespace}-monitoring-availability"
  schedule_expression = "cron(5/15 * * * ? *)"
}

resource "aws_cloudwatch_event_target" "monitoring_availability" {
  rule      = aws_cloudwatch_event_rule.monitoring_availability.name
  target_id = "start-monitoring-availability"
  arn       = aws_lambda_function.monitoring_availability.arn
}

resource "aws_lambda_permission" "allow_monitoring_availability" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.monitoring_availability.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.monitoring_availability.arn
}

########
# Cloudwatch - Eventbridge + Lambda for monitoring latency
########
resource "aws_lambda_function" "monitoring_latency" {
  function_name = "${local.namespace}-monitoring-latency"
  role          = aws_iam_role.lambda_monitoring_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = var.lambda_function_runtime
  filename      = "lambdas/${var.environment}/monitoring_latency/lambda_function_payload.zip"

  environment {
    variables = {
      LOG_GROUP                         = "/aws/lambda/latency-logging"
      NAMESPACE                         = local.namespace
      ENV                               = upper(var.environment)
      MONITORING_ALERT_TOPIC_ARN        = aws_sns_topic.monitoring_alert.arn
      MONITORING_NOTIFICATION_TOPIC_ARN = aws_sns_topic.monitoring_notification.arn
    }
  }
}

resource "aws_cloudwatch_event_rule" "monitoring_latency" {
  name                = "${local.namespace}-monitoring-latency"
  schedule_expression = "cron(0 */6 * * ? *)"
}

resource "aws_cloudwatch_event_target" "monitoring_latency" {
  rule      = aws_cloudwatch_event_rule.monitoring_latency.name
  target_id = "start-monitoring-latency"
  arn       = aws_lambda_function.monitoring_latency.arn
}

resource "aws_lambda_permission" "allow_monitoring_latency" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.monitoring_latency.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.monitoring_latency.arn
}

########
# SNS - topic + subscription for latency dashboard
########
resource "aws_sns_topic" "monitoring_alert" {
  name            = "${local.namespace}-monitoring-alert"
  delivery_policy = <<EOF
{
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultRequestPolicy": {
      "headerContentType": "text/plain; charset=UTF-8"
    }
  }
}
EOF
}

resource "aws_sns_topic" "monitoring_notification" {
  name            = "${local.namespace}-monitoring-notification"
  delivery_policy = <<EOF
{
  "http": {
    "defaultHealthyRetryPolicy": {
      "minDelayTarget": 20,
      "maxDelayTarget": 20,
      "numRetries": 3,
      "numMaxDelayRetries": 0,
      "numNoDelayRetries": 0,
      "numMinDelayRetries": 0,
      "backoffFunction": "linear"
    },
    "disableSubscriptionOverrides": false,
    "defaultRequestPolicy": {
      "headerContentType": "text/plain; charset=UTF-8"
    }
  }
}
EOF
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
      },
      {
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ],
        Resource = "*",
        Effect   = "Allow",
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
  timeout       = 120

  vpc_config {
    subnet_ids         = [aws_subnet.priv_subnet_1.id, aws_subnet.priv_subnet_2.id, aws_subnet.priv_subnet_3.id]
    security_group_ids = [aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id]
  }

  environment {
    variables = {
      DESTINATION_BUCKET = aws_s3_bucket.s3_backup_logs.id,
      LOG_GROUP          = "API-Gateway-Execution-Logs_${aws_api_gateway_rest_api.api.id}/${var.environment},/aws/eks/fluentbit-cloudwatch/workload/${var.k8s_namespace},/aws/eks/fluentbit-cloudwatch/workload/kube-system,/aws/eks/fluentbit-cloudwatch/workload/default"
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

########
# Monitoring - Internal/External call - Lambda
########
resource "aws_lambda_function" "latency_logging" {
  function_name = local.lambda_latency_function_name
  role          = aws_iam_role.lambda_s3_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = var.lambda_function_runtime
  filename      = "lambdas/${var.environment}/latency_logging/lambda_function_payload.zip"
  timeout       = 120

  vpc_config {
    subnet_ids         = [aws_subnet.priv_subnet_1.id, aws_subnet.priv_subnet_2.id, aws_subnet.priv_subnet_3.id]
    security_group_ids = [aws_eks_cluster.eks_cluster.vpc_config[0].cluster_security_group_id]
  }
}

resource "aws_iam_policy" "lambda_task_eks_pod" {
  name        = "lambda-task-eks-pods-policy"
  description = "IAM policy allowing Task to invoke lambda latency_logging"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "lambda:invokeFunction"
            ],
            "Resource": [
              "${aws_lambda_function.latency_logging.arn}"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eks_pod_6" {
  policy_arn = aws_iam_policy.lambda_task_eks_pod.arn
  role       = aws_iam_role.eks_serviceaccount["atm_layer_wf_task"].name
}
