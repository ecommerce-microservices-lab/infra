variable "cluster_name" {
  description = "The name of the Kubernetes cluster."
  type = string
  default = "microservices-cluster"
}

variable "location" {
  description = "The Azure region where the resources will be created."
  type = string
  default = "eastus2"
}

variable "resource_group_name" {
  description = "The name of the resource group where the resources will be created."
  type = string
  default = "microservices-rg"
}

variable "dns_prefix" {
  description = "The DNS prefix for the Kubernetes cluster."
  type = string
  default = "microservices"
}

variable "subscription_id" {
  description = "The ID of the Azure subscription where the resources will be created."
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
}

variable "client_secret" {
  description = "Azure client secret"
  type        = string
}

variable "client_id" {
  description = "Azure client ID"
  type        = string
}

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-east-2"
}

# Variables GCP
variable "gcp_project_id" {
  description = "GCP Project ID"
  type        = string
  default     = ""
}

variable "gcp_region" {
  description = "GCP Region"
  type        = string
  default     = "us-central1"
}

variable "gcp_zone" {
  description = "GCP Zone"
  type        = string
  default     = "us-central1-a"
}

variable "gcp_credentials_path" {
  description = "Path to GCP service account key JSON file"
  type        = string
  default     = ""
}

# Variables GKE
variable "gke_cluster_name" {
  description = "Name of the GKE cluster"
  type        = string
  default     = ""
}

variable "gke_node_count" {
  description = "Number of nodes in the GKE cluster"
  type        = number
  default     = 2
}

variable "gke_min_node_count" {
  description = "Minimum number of nodes for autoscaling"
  type        = number
  default     = 1
}

variable "gke_max_node_count" {
  description = "Maximum number of nodes for autoscaling"
  type        = number
  default     = 3
}

variable "gke_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-standard-4"
}

variable "gke_disk_size_gb" {
  description = "Disk size in GB for GKE nodes"
  type        = number
  default     = 20
}

variable "gke_preemptible" {
  description = "Use preemptible instances for GKE nodes"
  type        = bool
  default     = false
}

variable "gke_node_service_account_email" {
  description = "Service account email for GKE nodes (leave empty to use default)"
  type        = string
  default     = ""
}

variable "gke_node_pool_name" {
  description = "Name of the GKE node pool (optional, defaults to cluster_name-node-pool)"
  type        = string
  default     = "gke-prod-np-v2"  # Nombre del node pool actual en producción
}
