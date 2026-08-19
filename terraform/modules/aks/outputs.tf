output "cluster_name" {
  description = "AKS cluster name."
  value       = azurerm_kubernetes_cluster.this.name
}

output "cluster_id" {
  description = "AKS cluster resource ID."
  value       = azurerm_kubernetes_cluster.this.id
}

output "oidc_issuer_url" {
  description = "OIDC issuer URL for workload identity federation."
  value       = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "kubelet_identity" {
  description = "Kubelet managed identity attributes."
  value       = azurerm_kubernetes_cluster.this.kubelet_identity[0]
}

output "node_resource_group" {
  description = "Auto-generated node resource group name for the AKS cluster."
  value       = azurerm_kubernetes_cluster.this.node_resource_group
}
