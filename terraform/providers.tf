terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
  
  # Backend remoto en S3
  backend "s3" {
    bucket         = "microservices-terraform-state-658250199880"
    key            = "terraform/azure/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  tenant_id = var.tenant_id
  client_secret = var.client_secret
  client_id = var.client_id
}

provider "aws" {
  region = var.aws_region
}

# Provider de Google
# Nota: Si no hay GCP configurado, el módulo gke_prod tiene count=0, así que no se usará
provider "google" {
  project = var.gcp_project_id
  region  = var.gcp_region
  
  # Usar credenciales desde archivo JSON si se proporciona
  # Si no se proporciona, usar Application Default Credentials (ADC)
  # IMPORTANTE: En el workflow de Actions siempre se pasa gcp_credentials_path=/tmp/gcp-key.json
  # cuando hay GCP configurado, así que esto solo afecta ejecuciones locales sin GCP
  credentials = var.gcp_credentials_path != "" ? file(var.gcp_credentials_path) : null
}