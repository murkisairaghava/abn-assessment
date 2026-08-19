output "private_dns_zone_ids" {
  description = "Private DNS zone resource IDs keyed by logical zone key."
  value = {
    for key, zone in azurerm_private_dns_zone.this : key => zone.id
  }
}

output "private_dns_zone_names" {
  description = "Private DNS zone names keyed by logical zone key."
  value = {
    for key, zone in azurerm_private_dns_zone.this : key => zone.name
  }
}
