locals {
  sanitized_project = join("", regexall("[a-z0-9]", lower(var.project_name)))
  sanitized_env     = join("", regexall("[a-z0-9]", lower(var.environment)))

  # Storage account names must be globally unique, 3-24 chars, lowercase alphanumeric.
  storage_account_name = substr(
    "st${local.sanitized_project}${local.sanitized_env}${substr(md5("${var.resource_group_name}-${var.location}-${var.project_name}-${var.environment}"), 0, 6)}",
    0,
    24
  )
}

resource "azurerm_storage_account" "this" {
  name                              = local.storage_account_name
  resource_group_name               = var.resource_group_name
  location                          = var.location
  account_kind                      = "StorageV2"
  account_tier                      = "Standard"
  account_replication_type          = "LRS"
  min_tls_version                   = "TLS1_2"
  public_network_access_enabled     = false
  allow_nested_items_to_be_public   = false
  infrastructure_encryption_enabled = true
  tags                              = var.tags

  # Deny public network paths; private endpoint access is used for blob traffic.
  network_rules {
    default_action = "Deny"
    bypass         = []
  }

  # Blob service configuration.
  blob_properties {
    versioning_enabled  = true
    change_feed_enabled = true

    delete_retention_policy {
      days = 7
    }

    container_delete_retention_policy {
      days = 7
    }
  }
}

resource "azurerm_private_endpoint" "blob" {
  name                = "pep-${local.storage_account_name}-blob"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-${local.storage_account_name}-blob"
    private_connection_resource_id = azurerm_storage_account.this.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "pdzg-${local.storage_account_name}-blob"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}
