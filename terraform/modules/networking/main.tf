locals {
  nsg_names = {
    hub_dns                = "nsg-hub-dns-resolver"
    spoke_aks              = "nsg-spoke-aks"
    spoke_private_endpoint = "nsg-spoke-private-endpoint"
  }

  route_table_names = {
    hub_dns                = "rt-hub-dns-resolver"
    spoke_aks              = "rt-spoke-aks"
    spoke_private_endpoint = "rt-spoke-private-endpoint"
  }
}

resource "azurerm_virtual_network" "hub" {
  name                = var.hub_vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.hub_address_space
  tags                = var.tags
}

resource "azurerm_virtual_network" "spoke" {
  name                = var.spoke_vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.spoke_address_space
  tags                = var.tags
}

resource "azurerm_subnet" "hub_azure_firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = var.hub_azure_firewall_subnet_prefixes
}

resource "azurerm_subnet" "hub_dns_resolver" {
  name                 = "snet-dns-resolver"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = var.hub_dns_resolver_subnet_prefixes
}

resource "azurerm_subnet" "spoke_aks" {
  name                 = "snet-aks"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = var.spoke_aks_subnet_prefixes
}

resource "azurerm_subnet" "spoke_private_endpoint" {
  name                                      = "snet-private-endpoint"
  resource_group_name                       = var.resource_group_name
  virtual_network_name                      = azurerm_virtual_network.spoke.name
  address_prefixes                          = var.spoke_private_endpoint_subnet_prefixes
  private_endpoint_network_policies         = "Disabled"
}

resource "azurerm_network_security_group" "hub_dns" {
  name                = local.nsg_names.hub_dns
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_group" "spoke_aks" {
  name                = local.nsg_names.spoke_aks
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_network_security_group" "spoke_private_endpoint" {
  name                = local.nsg_names.spoke_private_endpoint
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_subnet_network_security_group_association" "hub_dns" {
  subnet_id                 = azurerm_subnet.hub_dns_resolver.id
  network_security_group_id = azurerm_network_security_group.hub_dns.id
}

resource "azurerm_subnet_network_security_group_association" "spoke_aks" {
  subnet_id                 = azurerm_subnet.spoke_aks.id
  network_security_group_id = azurerm_network_security_group.spoke_aks.id
}

resource "azurerm_subnet_network_security_group_association" "spoke_private_endpoint" {
  subnet_id                 = azurerm_subnet.spoke_private_endpoint.id
  network_security_group_id = azurerm_network_security_group.spoke_private_endpoint.id
}

resource "azurerm_route_table" "hub_dns" {
  name                = local.route_table_names.hub_dns
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_route_table" "spoke_aks" {
  name                = local.route_table_names.spoke_aks
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  dynamic "route" {
    for_each = var.spoke_default_route_next_hop_ip == null ? [] : [var.spoke_default_route_next_hop_ip]
    content {
      name                   = "default-to-firewall"
      address_prefix         = "0.0.0.0/0"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = route.value
    }
  }
}

resource "azurerm_route_table" "spoke_private_endpoint" {
  name                = local.route_table_names.spoke_private_endpoint
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  dynamic "route" {
    for_each = var.spoke_default_route_next_hop_ip == null ? [] : [var.spoke_default_route_next_hop_ip]
    content {
      name                   = "default-to-firewall"
      address_prefix         = "0.0.0.0/0"
      next_hop_type          = "VirtualAppliance"
      next_hop_in_ip_address = route.value
    }
  }
}

resource "azurerm_subnet_route_table_association" "hub_dns" {
  subnet_id      = azurerm_subnet.hub_dns_resolver.id
  route_table_id = azurerm_route_table.hub_dns.id
}

resource "azurerm_subnet_route_table_association" "spoke_aks" {
  subnet_id      = azurerm_subnet.spoke_aks.id
  route_table_id = azurerm_route_table.spoke_aks.id
}

resource "azurerm_subnet_route_table_association" "spoke_private_endpoint" {
  subnet_id      = azurerm_subnet.spoke_private_endpoint.id
  route_table_id = azurerm_route_table.spoke_private_endpoint.id
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = var.hub_to_spoke_peering_name
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = var.spoke_to_hub_peering_name
  resource_group_name          = var.resource_group_name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}
