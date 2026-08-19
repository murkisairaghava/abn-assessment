data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "this" {
  name                = var.keyvault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"

  rbac_authorization_enabled  = true
  purge_protection_enabled    = true
  soft_delete_retention_days  = 90
  public_network_access_enabled = false

  network_acls {
    bypass         = "None"
    default_action = "Deny"
  }

  tags = var.tags
}

resource "azurerm_private_endpoint" "this" {
  name                = "pep-${var.keyvault_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${var.keyvault_name}"
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdzg-${var.keyvault_name}"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}
