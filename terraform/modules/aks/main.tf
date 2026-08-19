locals {
  dns_prefix = substr(join("", regexall("[a-z0-9-]", lower(var.cluster_name))), 0, 54)
}

data "azurerm_client_config" "current" {}

data "azurerm_kubernetes_service_versions" "this" {
  location        = var.location
  include_preview = false
}

resource "azurerm_user_assigned_identity" "aks" {
  name                = "id-${var.cluster_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tags                = var.tags
}

resource "azurerm_kubernetes_cluster" "this" {
  name                                = var.cluster_name
  location                            = var.location
  resource_group_name                 = var.resource_group_name
  dns_prefix                          = local.dns_prefix
  kubernetes_version                  = data.azurerm_kubernetes_service_versions.this.latest_version
  private_cluster_enabled             = true
  private_cluster_public_fqdn_enabled = false
  role_based_access_control_enabled   = true
  oidc_issuer_enabled                 = true
  workload_identity_enabled           = true
  automatic_upgrade_channel           = "patch"
  local_account_disabled              = true
  tags                                = var.tags

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  azure_active_directory_role_based_access_control {
    tenant_id          = data.azurerm_client_config.current.tenant_id
    azure_rbac_enabled = true
  }

  default_node_pool {
    name                 = "system"
    vm_size              = "Standard_D4s_v5"
    type                 = "VirtualMachineScaleSets"
    vnet_subnet_id       = var.aks_subnet_id
    orchestrator_version = data.azurerm_kubernetes_service_versions.this.latest_version
    auto_scaling_enabled       = true
    min_count                  = 1
    max_count                  = 3
    max_pods                   = 30
    only_critical_addons_enabled = true
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "azure"
    pod_cidr            = var.pod_cidr
    service_cidr        = var.service_cidr
    dns_service_ip      = var.dns_service_ip
    load_balancer_sku   = "standard"
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }
}
