locals {
  private_dns_zones = {
    key_vault = "privatelink.vaultcore.azure.net"
    blob      = "privatelink.blob.core.windows.net"
    acr       = "privatelink.azurecr.io"
  }

  # Build a stable cross-product of zones x VNets so every zone is linked to every VNet.
  zone_vnet_links = {
    for pair in setproduct(keys(local.private_dns_zones), tolist(var.vnet_ids)) :
    "${pair[0]}-${substr(md5(pair[1]), 0, 8)}" => {
      zone_key = pair[0]
      vnet_id  = pair[1]
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
  name                  = "link-${each.value.zone_key}-${substr(md5(each.value.vnet_id), 0, 6)}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.this[each.value.zone_key].name
  virtual_network_id    = each.value.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}
