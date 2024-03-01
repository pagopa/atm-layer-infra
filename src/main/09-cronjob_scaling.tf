locals {
  lambda_function_name = "${local.namespace}-${var.lambda_function_name}"
}

########
# IAM + Lambda 
########
resource "aws_iam_role" "lambda_role" {
  count = var.night_shutdown == true ? 1 : 0

  name = "RDS-Managed-Lambda-Role"

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

resource "aws_iam_role_policy" "lambda_rds_policy" {
  count = var.night_shutdown == true ? 1 : 0

  name = "lambda_rds_policy"
  role = aws_iam_role.lambda_role[0].id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = [
          "rds:StartDBCluster",
          "rds:StopDBCluster"
        ],
        Effect   = "Allow",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "attach_lambda_basic_execution" {
  count = var.night_shutdown == true ? 1 : 0

  role       = aws_iam_role.lambda_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "rds_managed" {
  count = var.night_shutdown == true ? 1 : 0

  function_name = local.lambda_function_name
  role          = aws_iam_role.lambda_role[0].arn
  handler       = "lambda_function.lambda_handler"
  runtime       = var.lambda_function_runtime
  filename      = "lambdas/${var.environment}/rds_managed/lambda_function_payload.zip"

  environment {
    variables = {
      DBCLUSTER = aws_rds_cluster.rds.id
    }
  }
}

########
# Cloudwatch events + Permissions
########
resource "aws_cloudwatch_event_rule" "turn_off" {
  count = var.night_shutdown == true ? 1 : 0

  name                = "${local.namespace}-rds-turn-off-nightly"
  schedule_expression = var.cloudwatch_rule_turn_off
}

resource "aws_cloudwatch_event_target" "turn_off_target" {
  count = var.night_shutdown == true ? 1 : 0

  rule      = aws_cloudwatch_event_rule.turn_off[0].name
  target_id = "turn-off-nightly"
  arn       = aws_lambda_function.rds_managed[0].arn
  input     = "{\"action\":\"off\"}"
}

resource "aws_lambda_permission" "allow_off_cloudwatch" {
  count = var.night_shutdown == true ? 1 : 0

  statement_id  = "AllowExecutionFromCloudWatchTurnOff"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rds_managed[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.turn_off[0].arn
}

resource "aws_cloudwatch_event_rule" "turn_on" {
  count = var.night_shutdown == true ? 1 : 0

  name                = "${local.namespace}-rds-turn-on-workday"
  schedule_expression = var.cloudwatch_rule_turn_on # TURN ON Ogni giorno, Lun-Ven, alle 08:00 Rome
}

resource "aws_cloudwatch_event_target" "turn_on_target" {
  count = var.night_shutdown == true ? 1 : 0

  rule      = aws_cloudwatch_event_rule.turn_on[0].name
  target_id = "turn-on-workday"
  arn       = aws_lambda_function.rds_managed[0].arn
  input     = "{\"action\":\"on\"}"
}

resource "aws_lambda_permission" "allow_on_cloudwatch" {
  count = var.night_shutdown == true ? 1 : 0

  statement_id  = "AllowExecutionFromCloudWatchTurnOn"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rds_managed[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.turn_on[0].arn
}

########
# Autoscaling scheduled for EKS Node Group
########
resource "aws_autoscaling_schedule" "scale_down" {
  count = var.night_shutdown == true ? 1 : 0

  scheduled_action_name  = "${local.namespace}-scale-down-nightly"
  min_size               = 0
  max_size               = 0
  desired_capacity       = 0
  recurrence             = var.eks_scale_down_cron
  time_zone              = "Europe/Rome"
  autoscaling_group_name = aws_eks_node_group.eks_node_group.resources[0].autoscaling_groups[0].name
}

resource "aws_autoscaling_schedule" "scale_up" {
  count = var.night_shutdown == true ? 1 : 0

  scheduled_action_name  = "${local.namespace}-scale-up-worktime"
  min_size               = var.eks_cluster_scaling_min
  max_size               = var.eks_cluster_scaling_max
  desired_capacity       = var.eks_cluster_scaling_desired
  recurrence             = var.eks_scale_up_cron
  time_zone              = "Europe/Rome"
  autoscaling_group_name = aws_eks_node_group.eks_node_group.resources[0].autoscaling_groups[0].name
}

########
# Helm chart - downscaler
########
resource "helm_release" "kube_downscaler" {
  count = var.night_shutdown == true ? 1 : 0

  name       = "kube-downscaler"
  namespace  = var.k8s_kube_system_namespace
  repository = "https://charts.deliveryhero.io/"
  chart      = "kube-downscaler"
  version    = "0.5.1"
  depends_on = [aws_eks_cluster.eks_cluster]

  set {
    name  = "deployment.environment.DEFAULT_UPTIME"
    value = "Mon-Fri 11:44-18:55 Europe/Rome"
  }
}