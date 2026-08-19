locals {
  sanitized_project = join("", regexall("[a-z0-9]", lower(var.project_name)))
  sanitized_env     = join("", regexall("[a-z0-9]", lower(var.environment)))

  # ACR names must be globally unique, 5-50 chars, lowercase alphanumeric.
  acr_name = substr(
    "acr${local.sanitized_project}${local.sanitized_env}${substr(md5("${var.resource_group_name}-${var.location}-${var.project_name}-${var.environment}"), 0, 6)}",
    0,
    50
  )
}

resource "azurerm_container_registry" "this" {
  name                          = local.acr_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = "Premium"
  admin_enabled                 = false
  public_network_access_enabled = false
  anonymous_pull_enabled        = false
  tags                          = var.tags
}

resource "azurerm_private_endpoint" "this" {
  name                = "pep-${local.acr_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${local.acr_name}"
    private_connection_resource_id = azurerm_container_registry.this.id
    subresource_names              = ["registry"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdzg-${local.acr_name}"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}
