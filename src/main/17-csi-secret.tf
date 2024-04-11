########
# Secrets store - CSI driver to mount kube secrets on Pods
########
resource "helm_release" "csi_secrets_store" {
  name       = var.helm_csi_secrets_name
  namespace  = var.k8s_kube_system_namespace
  repository = var.helm_csi_secrets_chart_repository
  chart      = var.helm_csi_secrets_chart_name
  version    = var.helm_csi_secrets_chart_version

  depends_on = [aws_eks_cluster.eks_cluster]

  set {
    name  = "syncSecret.enabled"
    value = var.helm_csi_secrets_sync_secret
  }

  set {
    name  = "rotationPollInterval"
    value = var.helm_csi_secrets_rotation_poll_interval
  }

  set {
    name  = "enableSecretRotation"
    value = var.helm_csi_secrets_enable_secret_rotation
  }
}

########
# Secrets store - AWS secrets provider to use Secrets Manager as kube secrets
########
resource "helm_release" "secrets_provider_aws" {
  name       = var.helm_secrets_provider_aws_name
  namespace  = var.k8s_kube_system_namespace
  repository = var.helm_secrets_provider_aws_chart_repository
  chart      = var.helm_secrets_provider_aws_chart_name
  version    = var.helm_secrets_provider_aws_chart_version

  depends_on = [helm_release.csi_secrets_store]
}

########
# Secrets store - Reloader to restart pod when a kube secret changes
########
resource "helm_release" "reloader" {
  name       = var.helm_reloader_name
  namespace  = var.k8s_kube_system_namespace
  repository = var.helm_reloader_chart_repository
  chart      = var.helm_reloader_chart_name
  version    = var.helm_reloader_chart_version

  set {
    name  = "deployment.reloadOnChange"
    value = var.helm_reloader_enable_deployment_reload_on_change
  }

  depends_on = [aws_eks_cluster.eks_cluster]
}

########
# IAM role for service-account that needs Secret Manager access
########
data "aws_iam_openid_connect_provider" "eks_oidc" {
  url        = aws_eks_cluster.eks_cluster.identity[0].oidc[0].issuer
  depends_on = [aws_eks_cluster.eks_cluster]
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
