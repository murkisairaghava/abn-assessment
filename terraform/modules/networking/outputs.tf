output "vnet_ids" {
  description = "Hub and spoke VNet IDs."
  value = {
    hub   = azurerm_virtual_network.hub.id
    spoke = azurerm_virtual_network.spoke.id
  }
}

output "subnet_ids" {
  description = "Subnet IDs for hub and spoke subnets."
  value = {
    hub_azure_firewall     = azurerm_subnet.hub_azure_firewall.id
    hub_dns_resolver       = azurerm_subnet.hub_dns_resolver.id
    spoke_aks              = azurerm_subnet.spoke_aks.id
    spoke_private_endpoint = azurerm_subnet.spoke_private_endpoint.id
  }
}

output "route_table_ids" {
  description = "Route table IDs created by the module."
  value = {
    hub_dns                = azurerm_route_table.hub_dns.id
    spoke_aks              = azurerm_route_table.spoke_aks.id
    spoke_private_endpoint = azurerm_route_table.spoke_private_endpoint.id
  }
}

output "nsg_ids" {
  description = "Network security group IDs created by the module."
  value = {
    hub_dns                = azurerm_network_security_group.hub_dns.id
    spoke_aks              = azurerm_network_security_group.spoke_aks.id
    spoke_private_endpoint = azurerm_network_security_group.spoke_private_endpoint.id
  }
}
