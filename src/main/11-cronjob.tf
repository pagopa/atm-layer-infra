########
# IAM + Lambda 
########
resource "aws_iam_role" "lambda_role" {
  count = var.environment == "dev" ? 1 : 0

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
  count = var.environment == "dev" ? 1 : 0

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
  count = var.environment == "dev" ? 1 : 0

  role       = aws_iam_role.lambda_role[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "rds_managed" {
  count = var.environment == "dev" ? 1 : 0

  function_name = var.lambda_function_name
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
  count = var.environment == "dev" ? 1 : 0

  name                = "rds-turn-off-nightly"
  schedule_expression = var.cloudwatch_rule_turn_off
}

resource "aws_cloudwatch_event_target" "turn_off_target" {
  count = var.environment == "dev" ? 1 : 0

  rule      = aws_cloudwatch_event_rule.turn_off[0].name
  target_id = "turn-off-nightly"
  arn       = aws_lambda_function.rds_managed[0].arn
  input     = "{\"action\":\"off\"}"
}

resource "aws_lambda_permission" "allow_off_cloudwatch" {
  count = var.environment == "dev" ? 1 : 0

  statement_id  = "AllowExecutionFromCloudWatchTurnOff"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rds_managed[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.turn_off[0].arn
}

resource "aws_cloudwatch_event_rule" "turn_on" {
  count = var.environment == "dev" ? 1 : 0

  name                = "rds-turn-on-workday"
  schedule_expression = var.cloudwatch_rule_turn_on # TURN ON Ogni giorno, Lun-Ven, alle 08:00 Rome
}

resource "aws_cloudwatch_event_target" "turn_on_target" {
  count = var.environment == "dev" ? 1 : 0

  rule      = aws_cloudwatch_event_rule.turn_on[0].name
  target_id = "turn-on-workday"
  arn       = aws_lambda_function.rds_managed[0].arn
  input     = "{\"action\":\"on\"}"
}

resource "aws_lambda_permission" "allow_on_cloudwatch" {
  count = var.environment == "dev" ? 1 : 0

  statement_id  = "AllowExecutionFromCloudWatchTurnOn"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rds_managed[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.turn_on[0].arn
}
