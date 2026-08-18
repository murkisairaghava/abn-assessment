output "resource_group_id" {
  description = "Existing resource group ID used by the sandbox environment."
  value       = data.azurerm_resource_group.existing.id
}

output "resource_group_name" {
  description = "Existing resource group name used by the sandbox environment."
  value       = data.azurerm_resource_group.existing.name
}

output "resource_group_location" {
  description = "Location inherited from the existing resource group."
  value       = data.azurerm_resource_group.existing.location
}

output "networking_vnet_ids" {
  description = "Hub and spoke VNet IDs from the networking module."
  value       = module.networking.vnet_ids
}

output "networking_subnet_ids" {
  description = "Subnet IDs from the networking module."
  value       = module.networking.subnet_ids
}

output "networking_route_table_ids" {
  description = "Route table IDs from the networking module."
  value       = module.networking.route_table_ids
}

output "networking_nsg_ids" {
  description = "NSG IDs from the networking module."
  value       = module.networking.nsg_ids
}
