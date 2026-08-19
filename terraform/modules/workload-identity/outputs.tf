output "managed_identity_client_id" {
  description = "Client ID of the user assigned managed identity."
  value       = azurerm_user_assigned_identity.this.client_id
}

output "managed_identity_principal_id" {
  description = "Principal ID of the user assigned managed identity."
  value       = azurerm_user_assigned_identity.this.principal_id
}
