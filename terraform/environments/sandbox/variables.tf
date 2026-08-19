variable "resource_group_name" {
  description = "Name of the resource group for the Azure architecture assessment."
  type        = string
}

variable "environment" {
  description = "Environment short name used for naming across modules."
  type        = string
}

variable "project_name" {
  description = "Project name used for naming across modules."
  type        = string
}

variable "keyvault_name" {
  description = "Name of the Key Vault deployed by the sandbox environment."
  type        = string
}

variable "tags" {
  description = "Additional tags merged with baseline assessment tags."
  type        = map(string)
  default     = {}
}

variable "hub_vnet_name" {
  description = "Hub VNet name override for the networking module."
  type        = string
  default     = "vnet-hub-sbx"
}

variable "spoke_vnet_name" {
  description = "Spoke VNet name override for the networking module."
  type        = string
  default     = "vnet-spoke-sbx"
}

variable "hub_address_space" {
  description = "Hub VNet CIDR block(s)."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "spoke_address_space" {
  description = "Spoke VNet CIDR block(s)."
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "hub_azure_firewall_subnet_prefixes" {
  description = "CIDR block(s) for AzureFirewallSubnet."
  type        = list(string)
  default     = ["10.0.0.0/24"]
}

variable "hub_dns_resolver_subnet_prefixes" {
  description = "CIDR block(s) for hub DNS Resolver subnet."
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "spoke_aks_subnet_prefixes" {
  description = "CIDR block(s) for AKS subnet in the spoke VNet."
  type        = list(string)
  default     = ["10.1.0.0/22"]
}

variable "spoke_private_endpoint_subnet_prefixes" {
  description = "CIDR block(s) for private endpoint subnet in the spoke VNet."
  type        = list(string)
  default     = ["10.1.4.0/24"]
}

variable "spoke_default_route_next_hop_ip" {
  description = "Optional next hop IP for default route (for example, Azure Firewall private IP)."
  type        = string
  default     = null
}

variable "hub_to_spoke_peering_name" {
  description = "Name for hub-to-spoke VNet peering."
  type        = string
  default     = "peer-hub-to-spoke"
}

variable "spoke_to_hub_peering_name" {
  description = "Name for spoke-to-hub VNet peering."
  type        = string
  default     = "peer-spoke-to-hub"
}
