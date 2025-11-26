# Namespace
resource "kubernetes_namespace" "namespace" {
  metadata {
    name = var.namespace_name
    labels = merge(
      var.labels,
      {
        environment = var.environment
        managed-by  = "terraform"
      }
    )
  }
}

# ResourceQuota - Límites de recursos por namespace
resource "kubernetes_resource_quota" "quota" {
  count = var.enable_resource_quota ? 1 : 0

  metadata {
    name      = "${var.namespace_name}-quota"
    namespace = kubernetes_namespace.namespace.metadata[0].name
    labels = {
      environment = var.environment
      managed-by  = "terraform"
    }
  }

  spec {
    hard = var.resource_quota_limits
  }

  depends_on = [kubernetes_namespace.namespace]
}

# LimitRange - Límites por pod/container
resource "kubernetes_limit_range" "limit_range" {
  count = var.enable_limit_range ? 1 : 0

  metadata {
    name      = "${var.namespace_name}-limits"
    namespace = kubernetes_namespace.namespace.metadata[0].name
    labels = {
      environment = var.environment
      managed-by  = "terraform"
    }
  }

  spec {
    limit {
      type = "Container"
      default = var.default_limits
      default_request = var.default_requests
      max = var.max_limits
      min = var.min_limits
    }
  }

  depends_on = [kubernetes_namespace.namespace]
}

# NetworkPolicy - Aislamiento de red básico
resource "kubernetes_network_policy" "network_policy" {
  count = var.enable_network_policy ? 1 : 0

  metadata {
    name      = "${var.namespace_name}-network-policy"
    namespace = kubernetes_namespace.namespace.metadata[0].name
    labels = {
      environment = var.environment
      managed-by  = "terraform"
    }
  }

  spec {
    pod_selector {
      match_labels = {}
    }

    policy_types = ["Ingress", "Egress"]

    # Permitir tráfico dentro del mismo namespace
    ingress {
      from {
        namespace_selector {
          match_labels = {
            name = var.namespace_name
          }
        }
      }
    }

    # Permitir tráfico desde namespaces específicos (si se especifican)
    dynamic "ingress" {
      for_each = var.allowed_ingress_namespaces
      content {
        from {
          namespace_selector {
            match_labels = {
              name = ingress.value
            }
          }
        }
      }
    }

    # Permitir tráfico saliente a DNS y servicios del sistema
    egress {
      to {
        namespace_selector {
          match_labels = {
            name = "kube-system"
          }
        }
      }
      ports {
        protocol = "UDP"
        port     = "53"
      }
    }

    # Permitir tráfico saliente a otros namespaces permitidos
    dynamic "egress" {
      for_each = var.allowed_egress_namespaces
      content {
        to {
          namespace_selector {
            match_labels = {
              name = egress.value
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_namespace.namespace]
}


