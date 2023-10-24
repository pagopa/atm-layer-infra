locals {
  s3_name = "${local.namespace}-s3-model"
}

########
# S3 Bucket
########
resource "aws_s3_bucket" "s3" {
  bucket = local.s3_name
}

#######
# IAM Policy - Manage s3 from eks pods
########
resource "aws_iam_policy" "s3_eks_pod" {
  name        = "s3-model-eks-pods-policy"
  description = "IAM policy to manage s3 from pods"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
              "${aws_s3_bucket.s3.arn}",
              "${aws_s3_bucket.s3.arn}/*"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "eks_pod_1" {
  policy_arn = aws_iam_policy.s3_eks_pod.arn
  role       = aws_iam_role.eks_serviceaccount["atm_layer_model"].name
}
