locals {
  workspace_name = lower("law-${var.project_name}-${var.environment}")
  appi_name      = lower("appi-${var.project_name}-${var.environment}")
}

resource "azurerm_log_analytics_workspace" "this" {
  name                = local.workspace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "this" {
  name                = local.appi_name
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"

  # Workspace-based Application Insights.
  workspace_id = azurerm_log_analytics_workspace.this.id
  tags         = var.tags
}
