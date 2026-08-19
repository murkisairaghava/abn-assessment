output "workspace_id" {
  description = "Log Analytics workspace GUID."
  value       = azurerm_log_analytics_workspace.this.workspace_id
}

output "workspace_name" {
  description = "Log Analytics workspace name."
  value       = azurerm_log_analytics_workspace.this.name
}

output "workspace_resource_id" {
  description = "Log Analytics workspace Azure resource ID."
  value       = azurerm_log_analytics_workspace.this.id
}

output "application_insights_id" {
  description = "Application Insights Azure resource ID."
  value       = azurerm_application_insights.this.id
}

output "application_insights_connection_string" {
  description = "Application Insights connection string."
  value       = azurerm_application_insights.this.connection_string
  sensitive   = true
}
