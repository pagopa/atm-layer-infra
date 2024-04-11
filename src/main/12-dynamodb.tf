locals {
  table_name = "${local.namespace}-wf-task-trace-logs"
}

resource "aws_dynamodb_table" "trace_log" {
  name         = local.table_name
  hash_key     = "id"
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "id"
    type = "N"
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
