locals {
  private_dns_zones = {
    key_vault = "privatelink.vaultcore.azure.net"
    blob      = "privatelink.blob.core.windows.net"
    acr       = "privatelink.azurecr.io"
  }

  # Build a stable cross-product of zones x named VNets.
  # Keys are deterministic at plan-time because they come from map keys (for example: hub, spoke).
  # VNet IDs may still be unknown until apply, but those are values, not for_each keys.
  zone_vnet_links = {
    for pair in setproduct(keys(local.private_dns_zones), keys(var.vnet_ids)) :
    "${pair[0]}-${pair[1]}" => {
      zone_key = pair[0]
      vnet_key = pair[1]
      vnet_id  = var.vnet_ids[pair[1]]
    }
  }
}

resource "azurerm_private_dns_zone" "this" {
  for_each            = local.private_dns_zones
  name                = each.value
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each              = local.zone_vnet_links
  name                  = "link-${each.value.zone_key}-${each.value.vnet_key}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.value.zone_key].name
  virtual_network_id    = each.value.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}
