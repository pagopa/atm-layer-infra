########
# Fluent bit
########
resource "helm_release" "fluent_bit" {
  name       = var.helm_fluent_bit_name
  repository = var.helm_fluent_bit_chart_repository
  chart      = var.helm_fluent_bit_chart_name
  namespace  = var.k8s_kube_system_namespace
  version    = var.helm_fluent_bit_chart_version

  set {
    name  = "serviceAccount.create"
    value = var.helm_fluent_bit_create_serviceaccount
  }

  set {
    name  = "cloudWatchLogs.enabled"
    value = var.helm_fluent_bit_enabled_cloudwatchlogs
  }

  set {
    name  = "cloudWatchLogs.logGroupName"
    value = "/aws/eks/${aws_eks_cluster.eks_cluster.name}/logs"
  }

  set {
    name  = "cloudWatchLogs.region"
    value = var.aws_region
  }

  set {
    name  = "cloudWatchLogs.logRetentionDays"
    value = var.helm_fluent_bit_logretentiondays_cloudwatchlogs
  }

  set {
    name  = "elasticsearch.enabled"
    value = var.helm_fluent_bit_enabled_elasticsearch
  }

  set {
    name  = "elasticsearch.awsRegion"
    value = var.aws_region
  }
}