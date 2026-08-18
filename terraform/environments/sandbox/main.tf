# Baseline tags for architecture assessment artifacts.
# User-provided tags are merged and can override these defaults.
locals {
  baseline_tags = {
    environment = var.environment
    assessment  = "azure-architecture"
    managed_by  = "terraform"
  }

  effective_tags = merge(local.baseline_tags, var.tags)
}

# Networking module deploys the hub-spoke topology for the assessment:
# - Hub VNet and subnets (AzureFirewallSubnet, DNS Resolver)
# - Spoke VNet and subnets (AKS, Private Endpoint)
# - NSGs, route tables, and bidirectional VNet peering
module "networking" {
  source = "../../modules/networking"

  resource_group_name = data.azurerm_resource_group.existing.name
  location            = data.azurerm_resource_group.existing.location

  hub_vnet_name   = var.hub_vnet_name
  spoke_vnet_name = var.spoke_vnet_name

  hub_address_space   = var.hub_address_space
  spoke_address_space = var.spoke_address_space

  hub_azure_firewall_subnet_prefixes = var.hub_azure_firewall_subnet_prefixes
  hub_dns_resolver_subnet_prefixes   = var.hub_dns_resolver_subnet_prefixes

  spoke_aks_subnet_prefixes              = var.spoke_aks_subnet_prefixes
  spoke_private_endpoint_subnet_prefixes = var.spoke_private_endpoint_subnet_prefixes

  spoke_default_route_next_hop_ip = var.spoke_default_route_next_hop_ip
  hub_to_spoke_peering_name       = var.hub_to_spoke_peering_name
  spoke_to_hub_peering_name       = var.spoke_to_hub_peering_name

  tags = local.effective_tags
}

# Monitoring module deploys shared observability resources for the assessment:
# - Log Analytics Workspace
# - Workspace-based Application Insights
module "monitoring" {
  source = "../../modules/monitoring"

  resource_group_name = data.azurerm_resource_group.existing.name
  location            = data.azurerm_resource_group.existing.location
  tags                = local.effective_tags

  environment  = var.environment
  project_name = var.project_name
}

# Private DNS module deploys private DNS zones and links them to both hub and spoke VNets.
module "private_dns" {
  source = "../../modules/private-dns"

  resource_group_name = data.azurerm_resource_group.existing.name
  tags                = local.effective_tags
  vnet_ids = toset([
    module.networking.vnet_ids.hub,
    module.networking.vnet_ids.spoke
  ])
}

# Key Vault module deploys a private Key Vault integrated with private endpoint and private DNS.
module "keyvault" {
  source = "../../modules/keyvault"

  resource_group_name        = data.azurerm_resource_group.existing.name
  location                   = data.azurerm_resource_group.existing.location
  keyvault_name              = var.keyvault_name
  private_endpoint_subnet_id = module.networking.subnet_ids.spoke_private_endpoint
  private_dns_zone_id        = module.private_dns.private_dns_zone_ids["key_vault"]
  tags                       = local.effective_tags
}

# Storage module deploys a private storage account with blob private endpoint and DNS integration.
module "storage" {
  source = "../../modules/storage"

  resource_group_name        = data.azurerm_resource_group.existing.name
  location                   = data.azurerm_resource_group.existing.location
  environment                = var.environment
  project_name               = var.project_name
  private_endpoint_subnet_id = module.networking.subnet_ids.spoke_private_endpoint
  private_dns_zone_id        = module.private_dns.private_dns_zone_ids["blob"]
  tags                       = local.effective_tags
}

# ACR module deploys a private Azure Container Registry with private endpoint and DNS integration.
module "acr" {
  source = "../../modules/acr"

  resource_group_name        = data.azurerm_resource_group.existing.name
  location                   = data.azurerm_resource_group.existing.location
  environment                = var.environment
  project_name               = var.project_name
  private_endpoint_subnet_id = module.networking.subnet_ids.spoke_private_endpoint
  private_dns_zone_id        = module.private_dns.private_dns_zone_ids["acr"]
  tags                       = local.effective_tags
}

# AKS module deploys a private AKS cluster integrated with existing network and monitoring resources.
module "aks" {
  source = "../../modules/aks"

  resource_group_name        = data.azurerm_resource_group.existing.name
  location                   = data.azurerm_resource_group.existing.location
  cluster_name               = "aks-${var.project_name}-${var.environment}"
  aks_subnet_id              = module.networking.subnet_ids.spoke_aks
  log_analytics_workspace_id = module.monitoring.workspace_resource_id
  tags                       = local.effective_tags
}

# Workload identity module enables Microsoft Entra federation between AKS service account and a UAMI.
module "workload_identity" {
  source = "../../modules/workload-identity"

  resource_group_name             = data.azurerm_resource_group.existing.name
  location                        = data.azurerm_resource_group.existing.location
  managed_identity_name           = "mi-shows-api"
  aks_oidc_issuer_url             = module.aks.oidc_issuer_url
  kubernetes_namespace            = "app"
  kubernetes_service_account_name = "shows-api-sa"
  keyvault_id                     = module.keyvault.key_vault_id
  tags                            = local.effective_tags
}
