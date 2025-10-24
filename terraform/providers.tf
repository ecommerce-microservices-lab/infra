provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id = var.tenant_id
  client_secret= var.client_secret
  client_id = var.client_id
}

provider "aws" {
  region = var.aws_region
}