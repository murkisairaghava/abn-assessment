variable "resource_group_name" {
  description = "Resource group name where the user assigned managed identity is created."
  type        = string
}

variable "location" {
  description = "Azure region for the user assigned managed identity."
  type        = string
}

variable "managed_identity_name" {
  description = "Name of the user assigned managed identity used by Kubernetes workloads."
  type        = string
}

variable "aks_oidc_issuer_url" {
  description = "AKS OIDC issuer URL used for workload identity federation."
  type        = string
}

variable "kubernetes_namespace" {
  description = "Kubernetes namespace containing the service account."
  type        = string
}

variable "kubernetes_service_account_name" {
  description = "Kubernetes service account name federated with the managed identity."
  type        = string
}

variable "keyvault_id" {
  description = "Resource ID of the target Key Vault for role assignment."
  type        = string
}

variable "tags" {
  description = "Tags applied to supported resources in this module."
  type        = map(string)
  default     = {}
}
