output "resource_group_name" {
  description = "The Resource Group Name"
  value       = azurerm_resource_group.microservices_rg.name
}

output "aks_cluster_names" {
  description = "The names of all AKS clusters"
  value = {
    for k, m in module.aks :
    k => m.aks_cluster_name
  }
}

output "aks_hosts" {
  description = "The host URLs of all AKS clusters"
  value = {
    for k, m in module.aks :
    k => m.host
  }
  sensitive = true
}


output "aks_client_certificates" {
  description = "Client certificates of all AKS clusters"
  value = {
    for k, m in module.aks :
    k => m.client_certificate
  }
  sensitive = true
}

output "aks_client_keys" {
  description = "Client keys of all AKS clusters"
  value = {
    for k, m in module.aks :
    k => m.client_key
  }
  sensitive = true
}

output "aks_cluster_ca_certificates" {
  description = "Cluster CA certificates of all AKS clusters"
  value = {
    for k, m in module.aks :
    k => m.cluster_ca_certificate
  }
  sensitive = true
}

output "acr_name" {
  description = "Name of the Azure Container Registry"
  value       = azurerm_container_registry.microservices_acr.name
}

output "acr_login_server" {
  description = "Login server URL of the Azure Container Registry"
  value       = azurerm_container_registry.microservices_acr.login_server
}

output "acr_admin_username" {
  description = "Admin username for the Azure Container Registry"
  value       = azurerm_container_registry.microservices_acr.admin_username
  sensitive   = true
}

output "acr_admin_password" {
  description = "Admin password for the Azure Container Registry"
  value       = azurerm_container_registry.microservices_acr.admin_password
  sensitive   = true
}
