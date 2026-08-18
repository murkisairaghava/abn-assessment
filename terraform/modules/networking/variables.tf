variable "resource_group_name" {
  description = "Resource group where networking resources will be deployed."
  type        = string
}

variable "location" {
  description = "Azure region for networking resources."
  type        = string
}

variable "hub_vnet_name" {
  description = "Name of the hub virtual network."
  type        = string
  default     = "vnet-hub"
}

variable "spoke_vnet_name" {
  description = "Name of the spoke virtual network."
  type        = string
  default     = "vnet-spoke"
}

variable "hub_address_space" {
  description = "Address space for the hub VNet."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "spoke_address_space" {
  description = "Address space for the spoke VNet."
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "hub_azure_firewall_subnet_prefixes" {
  description = "Address prefixes for AzureFirewallSubnet in the hub VNet."
  type        = list(string)
  default     = ["10.0.0.0/24"]
}

variable "hub_dns_resolver_subnet_prefixes" {
  description = "Address prefixes for DNS resolver subnet in the hub VNet."
  type        = list(string)
  default     = ["10.0.1.0/24"]
}

variable "spoke_aks_subnet_prefixes" {
  description = "Address prefixes for the AKS subnet in the spoke VNet."
  type        = list(string)
  default     = ["10.1.0.0/22"]
}

variable "spoke_private_endpoint_subnet_prefixes" {
  description = "Address prefixes for the private endpoint subnet in the spoke VNet."
  type        = list(string)
  default     = ["10.1.4.0/24"]
}

variable "spoke_default_route_next_hop_ip" {
  description = "Optional next-hop IP for a 0.0.0.0/0 route in spoke route tables (for example, Azure Firewall private IP)."
  type        = string
  default     = null
}

variable "hub_to_spoke_peering_name" {
  description = "Name of the hub-to-spoke VNet peering."
  type        = string
  default     = "peer-hub-to-spoke"
}

variable "spoke_to_hub_peering_name" {
  description = "Name of the spoke-to-hub VNet peering."
  type        = string
  default     = "peer-spoke-to-hub"
}

variable "tags" {
  description = "Tags applied to all supported resources."
  type        = map(string)
  default     = {}
}
