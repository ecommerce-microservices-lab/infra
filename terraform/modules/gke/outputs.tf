output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.gke.name
}

output "cluster_endpoint" {
  description = "Endpoint for the GKE cluster"
  value       = google_container_cluster.gke.endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Base64 encoded public certificate for the cluster"
  value       = google_container_cluster.gke.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "cluster_location" {
  description = "Location of the GKE cluster"
  value       = google_container_cluster.gke.location
}

output "cluster_region" {
  description = "Region of the GKE cluster"
  value       = var.region
}

output "cluster_zone" {
  description = "Zone of the GKE cluster"
  value       = var.zone
}

output "vpc_name" {
  description = "Name of the VPC"
  value       = google_compute_network.gke_vpc.name
}

output "subnet_name" {
  description = "Name of the subnet"
  value       = google_compute_subnetwork.gke_subnet.name
}

output "cluster_token" {
  description = "Token for authenticating with the GKE cluster"
  value       = data.google_client_config.default.access_token
  sensitive   = true
}

