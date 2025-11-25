# Data source para obtener el token de autenticación
data "google_client_config" "default" {}

# VPC para GKE
resource "google_compute_network" "gke_vpc" {
  name                    = "${var.cluster_name}-vpc"
  auto_create_subnetworks = false
}

# Subnet para GKE con secondary ranges para pods y services
resource "google_compute_subnetwork" "gke_subnet" {
  name          = "${var.cluster_name}-subnet"
  ip_cidr_range = var.subnet_cidr
  region        = var.region
  network       = google_compute_network.gke_vpc.id
  
  # Secondary ranges para pods y services (requerido para VPC_NATIVE)
  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.pods_cidr
  }
  
  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.services_cidr
  }
}

# Cluster GKE
resource "google_container_cluster" "gke" {
  name     = var.cluster_name
  location = var.zone
  
  # Eliminar el nodo por defecto (usaremos node pools separados)
  remove_default_node_pool = true
  initial_node_count         = 1

  network    = google_compute_network.gke_vpc.name
  subnetwork = google_compute_subnetwork.gke_subnet.name

  # Configuración de red
  networking_mode = "VPC_NATIVE"
  
  # Configuración de IP ranges
  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name  = "services"
  }

  # Configuración de master
  master_auth {
    client_certificate_config {
      issue_client_certificate = false
    }
  }

  # Configuración de release channel (para actualizaciones automáticas)
  release_channel {
    channel = "REGULAR"
  }

  # Configuración de mantenimiento
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00"
    }
  }

  # Configuración de logging y monitoring
  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  # Configuración de addons
  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }

  # Configuración de private cluster (opcional, descomentar si necesitas)
  # private_cluster_config {
  #   enable_private_nodes    = true
  #   enable_private_endpoint = false
  #   master_ipv4_cidr_block  = "172.16.0.0/28"
  # }

  # Labels
  resource_labels = var.labels

  # Lifecycle: evitar recrear el cluster si cambian algunos parámetros
  lifecycle {
    ignore_changes = [
      node_config,
      node_pool,
    ]
  }
}

# Node Pool para el cluster
resource "google_container_node_pool" "gke_nodes" {
  name    = var.node_pool_name != "" ? var.node_pool_name : "${var.cluster_name}-node-pool"
  location = var.zone
  cluster  = google_container_cluster.gke.name
  
  # Cuando hay autoscaling, usar initial_node_count en lugar de node_count
  initial_node_count = var.node_count

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    preemptible  = var.preemptible
    machine_type = var.machine_type
    disk_size_gb = var.disk_size_gb
    disk_type    = var.disk_type

    # Service Account para los nodos (solo si se especifica)
    # Si está vacío, GKE usa el Service Account por defecto del proyecto
    service_account = var.node_service_account_email != "" ? var.node_service_account_email : null

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    labels = var.node_labels

    # Configuración de metadata
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  autoscaling {
    min_node_count = var.min_node_count
    max_node_count = var.max_node_count
  }

  # Ignorar cambios en atributos que usan valores por defecto de GKE
  # - initial_node_count: GKE maneja el node_count automáticamente con autoscaling
  # - node_config[0].oauth_scopes: Usar los scopes por defecto de GKE (más seguros)
  # - node_config[0].service_account: GKE usa "default" cuando es null
  lifecycle {
    ignore_changes = [
      initial_node_count,
      node_config[0].oauth_scopes,
      node_config[0].service_account
    ]
  }
}

