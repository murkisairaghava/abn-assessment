variable "resource_group_name" {
  description = "Name of the resource group where AKS and related resources are deployed."
  type        = string
}

variable "location" {
  description = "Azure region for AKS deployment."
  type        = string
}

variable "cluster_name" {
  description = "AKS cluster name."
  type        = string
}

variable "aks_subnet_id" {
  description = "Subnet ID used by the AKS system node pool."
  type        = string
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace resource ID for Container Insights integration."
  type        = string
}

variable "tags" {
  description = "Tags applied to AKS and supporting resources."
  type        = map(string)
  default     = {}
}

variable "pod_cidr" {
  description = "Pod CIDR used by Azure CNI Overlay."
  type        = string
  default     = "10.244.0.0/16"
}

variable "service_cidr" {
  description = "Kubernetes service CIDR."
  type        = string
  default     = "10.240.0.0/16"
}

variable "dns_service_ip" {
  description = "Kubernetes DNS service IP."
  type        = string
  default     = "10.240.0.10"
}
