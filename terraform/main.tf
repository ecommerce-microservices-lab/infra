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

provider "kubernetes" {
  host                   = module.aks.host
  client_certificate     = base64decode(module.aks.client_certificate)
  client_key             = base64decode(module.aks.client_key)
  cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)
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
