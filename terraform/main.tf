resource "random_id" "acr_suffix" {
  byte_length = 4
}

resource "azurerm_resource_group" "microservices_rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_container_registry" "microservices_acr" {
  name                = "microservicesacr${random_id.acr_suffix.hex}"
  resource_group_name = azurerm_resource_group.microservices_rg.name
  location            = azurerm_resource_group.microservices_rg.location
  sku                 = "Basic"
  admin_enabled       = true
}

module "aks" {

  source = "./modules/aks"

  for_each = {

    # Usando el cluster prod que ya existe
    prod = {
      location     = "eastus2"
      cluster_name = "${var.cluster_name}-prod"
      dns_prefix   = "${var.dns_prefix}-prod"
      node_count   = 2
      vm_size      = "Standard_D2s_v3"
      tags = {
        environment = "prod"
        project     = "microservices"
      }
    }

    # TODO: Desplegar después de verificar que stage funciona
    # prod = {
    #   location     = "eastus2"
    #   cluster_name = "${var.cluster_name}-prod"
    #   dns_prefix   = "${var.dns_prefix}-prod"
    #   node_count   = 2
    #   vm_size      = "Standard_D2s_v3"
    #   tags = {
    #     environment = "prod"
    #     project     = "microservices"
    #   }
    # }

    # devops = {
    #   location     = "eastus2"
    #   cluster_name = "${var.cluster_name}-devops"
    #   dns_prefix   = "${var.dns_prefix}-devops"
    #   node_count   = 2
    #   vm_size      = "Standard_D2s_v3"
    #   tags = {
    #     environment = "devops"
    #     project     = "microservices"
    #   }
    # }

  }
  location            = each.value.location
  cluster_name        = each.value.cluster_name
  resource_group_name = azurerm_resource_group.microservices_rg.name
  dns_prefix          = each.value.dns_prefix
  node_count          = each.value.node_count
  vm_size             = each.value.vm_size
  tags                = each.value.tags
}

# Módulo GKE para producción (GCP)
module "gke_prod" {
  source = "./modules/gke"

  cluster_name = var.gke_cluster_name != "" ? var.gke_cluster_name : "${var.cluster_name}-gke-prod"
  region       = var.gcp_region
  zone         = var.gcp_zone

  node_pool_name = var.gke_node_pool_name

  node_count = var.gke_node_count
  min_node_count = var.gke_min_node_count
  max_node_count = var.gke_max_node_count

  machine_type = var.gke_machine_type
  disk_size_gb = var.gke_disk_size_gb
  preemptible  = var.gke_preemptible

  node_service_account_email = var.gke_node_service_account_email

  labels = {
    environment = "prod"
    project     = "microservices"
    managed-by  = "terraform"
  }

  node_labels = {
    environment = "prod"
    project     = "microservices"
  }
}

# Provider de Kubernetes para Azure AKS
provider "kubernetes" {
  alias                  = "aks"
  host                   = module.aks["prod"].host
  client_certificate     = base64decode(module.aks["prod"].client_certificate)
  client_key             = base64decode(module.aks["prod"].client_key)
  cluster_ca_certificate = base64decode(module.aks["prod"].cluster_ca_certificate)
}

# Data source para obtener token de GCP (debe estar antes del provider)
data "google_client_config" "gke" {
  count = var.gcp_project_id != "" ? 1 : 0
}

# Provider de Kubernetes para GCP GKE
# IMPORTANTE: Este provider solo se usa cuando hay GCP configurado
# El módulo namespace_prod tiene count=0 cuando no hay GCP, así que el provider no se usa
# En el workflow de Actions siempre se pasa gcp_project_id cuando hay GCP configurado
# Usamos try() para manejar el caso cuando el módulo aún no existe en el estado
provider "kubernetes" {
  alias                  = "gke"
  host                   = try(module.gke_prod.cluster_endpoint, "")
  token                  = var.gcp_project_id != "" ? try(data.google_client_config.gke[0].access_token, "") : ""
  cluster_ca_certificate = try(base64decode(module.gke_prod.cluster_ca_certificate), "")
}

# Namespace 'dev' en Azure AKS
# Nota: Este namespace maneja tanto 'dev' como 'stage' usando tags de imagen
module "namespace_dev" {
  source = "./modules/namespace"
  providers = {
    kubernetes = kubernetes.aks
  }

  namespace_name = "dev"
  environment    = "dev"

  labels = {
    project = "microservices"
    # Nota: Los labels de Kubernetes no pueden tener espacios ni paréntesis
  }

  # ResourceQuota más permisivo para desarrollo
  enable_resource_quota = true
  resource_quota_limits = {
    "requests.cpu"    = "8"
    "requests.memory" = "16Gi"
    "limits.cpu"      = "16"
    "limits.memory"   = "32Gi"
    "pods"            = "100"
  }

  # LimitRange para desarrollo
  enable_limit_range = true
  default_limits = {
    cpu    = "1"
    memory = "1Gi"
  }
  default_requests = {
    cpu    = "100m"
    memory = "128Mi"
  }
  max_limits = {
    cpu    = "4"
    memory = "4Gi"
  }

  # NetworkPolicy: permitir comunicación con otros namespaces
  enable_network_policy = true
  allowed_ingress_namespaces = []
  allowed_egress_namespaces   = []
}

# Namespace 'prod' en GCP GKE
module "namespace_prod" {
  source = "./modules/namespace"
  providers = {
    kubernetes = kubernetes.gke
  }

  count = var.gcp_project_id != "" ? 1 : 0

  namespace_name = "prod"
  environment    = "prod"

  labels = {
    project = "microservices"
    # Nota: Los labels de Kubernetes no pueden tener espacios ni paréntesis
  }

  # ResourceQuota más estricto para producción
  enable_resource_quota = true
  resource_quota_limits = {
    "requests.cpu"    = "16"
    "requests.memory" = "32Gi"
    "limits.cpu"      = "32"
    "limits.memory"   = "64Gi"
    "pods"            = "200"
  }

  # LimitRange para producción
  enable_limit_range = true
  default_limits = {
    cpu    = "2"
    memory = "2Gi"
  }
  default_requests = {
    cpu    = "200m"
    memory = "256Mi"
  }
  max_limits = {
    cpu    = "8"
    memory = "8Gi"
  }

  # NetworkPolicy más restrictivo para producción
  enable_network_policy = true
  allowed_ingress_namespaces = []
  allowed_egress_namespaces   = []
}

# Backend remoto en S3 (descomentar después de crear el bucket)
# terraform {
#   backend "s3" {
#     bucket         = "microservices-state-bucket"
#     key            = "terraform/azure/terraform.tfstate"
#     region         = "us-east-2"
#     encrypt        = true
#     dynamodb_table = "terraform-state-lock"
#   }
# }
