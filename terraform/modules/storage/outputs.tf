output "storage_account_name" {
  description = "Storage account name."
  value       = azurerm_storage_account.this.name
}

output "storage_account_id" {
  description = "Storage account resource ID."
  value       = azurerm_storage_account.this.id
}

output "primary_blob_endpoint" {
  description = "Primary blob endpoint URL."
  value       = azurerm_storage_account.this.primary_blob_endpoint
}

output "private_endpoint_id" {
  description = "Private endpoint resource ID for blob access."
  value       = azurerm_private_endpoint.blob.id
}
