########
# Metrics server - Metrics collection for pods
########
resource "helm_release" "metrics_server" {
  name       = var.helm_metrics_server_name
  repository = var.helm_metrics_server_chart_repository
  chart      = var.helm_metrics_server_chart_name
  namespace  = var.k8s_kube_system_namespace
  version    = var.helm_metrics_server_chart_version

  set {
    name  = "image.repository"
    value = "${local.account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/k8s/metrics-server/metrics-server"
  }

  set {
    name  = "image.tag"
    value = "v0.6.3"
  }

  set {
    name  = "replicas"
    value = var.helm_metrics_server_replicas
  }
}