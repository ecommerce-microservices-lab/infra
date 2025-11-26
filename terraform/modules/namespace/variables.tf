variable "namespace_name" {
  description = "Name of the Kubernetes namespace"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, stage, prod)"
  type        = string
}

variable "labels" {
  description = "Additional labels for the namespace"
  type        = map(string)
  default     = {}
}

# ResourceQuota configuration
variable "enable_resource_quota" {
  description = "Enable ResourceQuota for the namespace"
  type        = bool
  default     = true
}

variable "resource_quota_limits" {
  description = "Resource quota limits for the namespace"
  type        = map(string)
  default = {
    "requests.cpu"    = "4"
    "requests.memory" = "8Gi"
    "limits.cpu"      = "8"
    "limits.memory"   = "16Gi"
    "pods"            = "50"
  }
}

# LimitRange configuration
variable "enable_limit_range" {
  description = "Enable LimitRange for the namespace"
  type        = bool
  default     = true
}

variable "default_limits" {
  description = "Default resource limits for containers"
  type        = map(string)
  default = {
    cpu    = "500m"
    memory = "512Mi"
  }
}

variable "default_requests" {
  description = "Default resource requests for containers"
  type        = map(string)
  default = {
    cpu    = "100m"
    memory = "128Mi"
  }
}

variable "max_limits" {
  description = "Maximum resource limits for containers"
  type        = map(string)
  default = {
    cpu    = "2"
    memory = "2Gi"
  }
}

variable "min_limits" {
  description = "Minimum resource limits for containers"
  type        = map(string)
  default = {
    cpu    = "50m"
    memory = "64Mi"
  }
}

# NetworkPolicy configuration
variable "enable_network_policy" {
  description = "Enable NetworkPolicy for the namespace"
  type        = bool
  default     = true
}

variable "allowed_ingress_namespaces" {
  description = "List of namespaces allowed to send traffic to this namespace"
  type        = list(string)
  default     = []
}

variable "allowed_egress_namespaces" {
  description = "List of namespaces this namespace is allowed to send traffic to"
  type        = list(string)
  default     = []
}


