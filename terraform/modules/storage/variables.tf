variable "resource_group_name" {
  description = "Name of the resource group where storage resources are deployed."
  type        = string
}

variable "location" {
  description = "Azure region for storage resources."
  type        = string
}

variable "environment" {
  description = "Environment short name used for naming (for example, sbx, dev, prod)."
  type        = string
}

variable "project_name" {
  description = "Project name used for storage account naming."
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID where the storage private endpoint will be deployed."
  type        = string
}

variable "private_dns_zone_id" {
  description = "Resource ID of the existing private DNS zone privatelink.blob.core.windows.net."
  type        = string
}

variable "tags" {
  description = "Tags applied to all module resources."
  type        = map(string)
  default     = {}
}
