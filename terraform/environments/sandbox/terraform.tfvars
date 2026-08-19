resource_group_name = "nebula-sandbox-saimurki-b394f87b"
environment         = "sandbox"
project_name        = "abn-assessment"
keyvault_name       = "kv-abn-sbx-b394f87b"

tags = {
  environment = "sandbox"
  workload    = "azure-architecture-assessment"
  owner       = "platform-team"
  managed_by  = "terraform"
  cost_center = "cc-1000"
}

hub_vnet_name   = "vnet-abn-hub-sbx"
spoke_vnet_name = "vnet-abn-spoke-sbx"

hub_address_space   = ["10.0.0.0/16"]
spoke_address_space = ["10.1.0.0/16"]

hub_azure_firewall_subnet_prefixes = ["10.0.0.0/24"]
hub_dns_resolver_subnet_prefixes   = ["10.0.1.0/24"]

spoke_aks_subnet_prefixes              = ["10.1.0.0/22"]
spoke_private_endpoint_subnet_prefixes = ["10.1.4.0/24"]

# Leave null until firewall private IP is known.
spoke_default_route_next_hop_ip = null

hub_to_spoke_peering_name = "peer-hub-to-spoke"
spoke_to_hub_peering_name = "peer-spoke-to-hub"
