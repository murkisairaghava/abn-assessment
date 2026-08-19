output "acr_id" {
  description = "Resource ID of the Azure Container Registry."
  value       = azurerm_container_registry.this.id
}

output "acr_name" {
  description = "Name of the Azure Container Registry."
  value       = azurerm_container_registry.this.name
}

output "login_server" {
  description = "Login server URL of the Azure Container Registry."
  value       = azurerm_container_registry.this.login_server
}

output "private_endpoint_id" {
  description = "Resource ID of the ACR private endpoint."
  value       = azurerm_private_endpoint.this.id
}
