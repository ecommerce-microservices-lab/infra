output "namespace_name" {
  description = "Name of the created namespace"
  value       = kubernetes_namespace.namespace.metadata[0].name
}

output "namespace_id" {
  description = "ID of the created namespace"
  value       = kubernetes_namespace.namespace.metadata[0].uid
}

output "resource_quota_id" {
  description = "ID of the ResourceQuota (if enabled)"
  value       = var.enable_resource_quota ? kubernetes_resource_quota.quota[0].id : null
}

output "limit_range_id" {
  description = "ID of the LimitRange (if enabled)"
  value       = var.enable_limit_range ? kubernetes_limit_range.limit_range[0].id : null
}

output "network_policy_id" {
  description = "ID of the NetworkPolicy (if enabled)"
  value       = var.enable_network_policy ? kubernetes_network_policy.network_policy[0].id : null
}


