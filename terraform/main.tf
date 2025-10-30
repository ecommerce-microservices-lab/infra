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

provider "kubernetes" {
  host                   = module.aks.host
  client_certificate     = base64decode(module.aks.client_certificate)
  client_key             = base64decode(module.aks.client_key)
  cluster_ca_certificate = base64decode(module.aks.cluster_ca_certificate)
}

# terraform {
#   backend "s3" {
#     bucket  = "microservices-state-bucket"
#     key     = "terraform/terraform.tfstate"
#     region  = "us-east-2"
#     encrypt = true
#   }
# }
