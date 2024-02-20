########
# Jaeger - Tracer
########
resource "helm_release" "jeager" {
  name       = var.helm_jaeger_name
  repository = var.helm_jaeger_chart_repository
  chart      = var.helm_jaeger_chart_name
  namespace  = "default"
  version    = var.helm_jaeger_chart_version

  set {
    name  = "provisionDataStore.cassandra"
    value = var.helm_jaeger_provisionDataStore_cassandra
  }

  set {
    name  = "allInOne.enabled"
    value = var.helm_jaeger_allinone_enabled
  }

  set {
    name  = "allInOne.resources.limits.memory"
    value = var.helm_jaeger_allinone_limits_memory
  }

  set {
    name  = "storage.type"
    value = var.helm_jaeger_storage_type
  }

  set {
    name  = "agent.enabled"
    value = var.helm_jaeger_agent_enabled
  }

  set {
    name  = "collector.enabled"
    value = var.helm_jaeger_collector_enabled
  }

  set {
    name  = "query.enabled"
    value = var.helm_jaeger_query_enabled
  }
}


