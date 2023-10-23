########
# Secrets store - CSI driver to mount kube secrets on Pods
########
resource "helm_release" "csi_secrets_store" {
  name       = "csi-secrets-store"
  namespace  = "kube-system"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  version    = "1.3.4"

  depends_on = [aws_eks_cluster.eks_cluster]

  set {
    name  = "syncSecret.enabled"
    value = "true"
  }

  set {
    name  = "rotationPollInterval"
    value = "10s"
  }

  set {
    name  = "enableSecretRotation"
    value = "true"
  }
}

########
# Secrets store - AWS secrets provider to use Secrets Manager as kube secrets
########
resource "helm_release" "secrets_provider_aws" {
  name       = "secrets-provider-aws"
  namespace  = "kube-system"
  repository = "https://aws.github.io/secrets-store-csi-driver-provider-aws"
  chart      = "secrets-store-csi-driver-provider-aws"
  version    = "0.3.4"

  depends_on = [helm_release.csi_secrets_store]
}

########
# Secrets store - Reloader to restart pod when a kube secret changes
########
resource "helm_release" "reloader" {
  name       = "reloader"
  namespace  = "kube-system"
  repository = "https://stakater.github.io/stakater-charts"
  chart      = "reloader"
  version    = "1.0.46"

  set {
    name  = "deployment.reloadOnChange"
    value = "true"
  }

  depends_on = [aws_eks_cluster.eks_cluster]
}

########
# IAM role for service-account that needs Secret Manager access
########
data "aws_iam_openid_connect_provider" "eks_oidc" {
  url = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
}

resource "aws_iam_role" "eks_serviceaccount" {
  for_each = var.services

  name = "${local.namespace}-${each.value.name}-serviceaccount-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          "Federated" : "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/${replace(data.aws_iam_openid_connect_provider.eks_oidc.url, "https://", "")}"
        },
        Action = "sts:AssumeRoleWithWebIdentity",
        Condition = {
          StringEquals = {
            "${replace(data.aws_iam_openid_connect_provider.eks_oidc.url, "https://", "")}:aud" : "sts.amazonaws.com",
            "${replace(data.aws_iam_openid_connect_provider.eks_oidc.url, "https://", "")}:sub" : "system:serviceaccount:pagopa:${local.namespace}-${each.value.name}"
          }
        }
      }
    ]
  })

  inline_policy {
    name = "eks-serviceaccount-secrets-policy"

    policy = jsonencode({
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "secretsmanager:GetSecretValue",
            "secretsmanager:DescribeSecret"
          ],
          Resource = "*"
        }
      ]
    })
  }
}
