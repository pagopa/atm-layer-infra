locals {
  table_name_trace_logs         = "pagopa-atm-layer-wf-task-trace-logs"
  table_name_instance_variables = "pagopa-atm-layer-wf-process-instance-variables"
  table_name_monitoring         = "pagopa-atm-layer-monitoring"
}

#######
# DynamoDB Table - To enable trace log
########
resource "aws_dynamodb_table" "trace_log" {
  name                        = local.table_name_trace_logs
  hash_key                    = "id"
  billing_mode                = "PAY_PER_REQUEST"
  deletion_protection_enabled = true

  attribute {
    name = "id"
    type = "S"
  }
}

#######
# IAM Policy - Allow TASK to read from dynamodb table from eks pods
########
resource "aws_iam_policy" "dynamo_task_eks_pod" {
  name        = "dynamodb-task-eks-pods-policy"
  description = "IAM policy to manage dyanmodb from pods"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:Scan",
                "dynamodb:Query",
                "dynamodb:GetItem",
                "dynamodb:List*"
            ],
            "Resource": [
              "${aws_dynamodb_table.trace_log.arn}"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eks_pod_3" {
  policy_arn = aws_iam_policy.dynamo_task_eks_pod.arn
  role       = aws_iam_role.eks_serviceaccount["atm_layer_wf_task"].name
}

#######
# DynamoDB Table - To manage Camunda variable
########
resource "aws_dynamodb_table" "instance_variables" {
  name                        = local.table_name_instance_variables
  hash_key                    = "name"
  billing_mode                = "PAY_PER_REQUEST"
  deletion_protection_enabled = true


  attribute {
    name = "name"
    type = "S"
  }
}

#######
# IAM Policy - Allow PROCESS to read from dynamodb table from eks pods
########
resource "aws_iam_policy" "dynamo_process_eks_pod" {
  name        = "dynamodb-process-eks-pods-policy"
  description = "IAM policy to manage dyanmodb from pods"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:Scan",
                "dynamodb:Query",
                "dynamodb:GetItem",
                "dynamodb:List*"
            ],
            "Resource": [
              "${aws_dynamodb_table.instance_variables.arn}"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eks_pod_4" {
  policy_arn = aws_iam_policy.dynamo_process_eks_pod.arn
  role       = aws_iam_role.eks_serviceaccount["atm_layer_wf_process"].name
}

#######
# DynamoDB Table - To track monitoring ticket
########
resource "aws_dynamodb_table" "monitoring" {
  name                        = local.table_name_monitoring
  hash_key                    = "id"
  billing_mode                = "PAY_PER_REQUEST"
  deletion_protection_enabled = true

  attribute {
    name = "id"
    type = "S"
  }
}

