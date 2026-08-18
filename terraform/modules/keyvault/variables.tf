variable "resource_group_name" {
  description = "Name of the resource group where Key Vault and private endpoint are deployed."
  type        = string
}

variable "location" {
  description = "Azure region for Key Vault and private endpoint."
  type        = string
}

variable "keyvault_name" {
  description = "Name of the Key Vault."
  type        = string
}

variable "private_endpoint_subnet_id" {
  description = "Subnet ID where the Key Vault private endpoint will be created."
  type        = string
}

variable "private_dns_zone_id" {
  description = "Resource ID of the existing private DNS zone privatelink.vaultcore.azure.net."
  type        = string
}

variable "tags" {
  description = "Tags applied consistently to resources."
  type        = map(string)
  default     = {}
}
