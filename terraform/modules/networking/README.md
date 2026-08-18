# networking module

Creates a hub-and-spoke network foundation with subnets, NSGs, route tables, and bidirectional VNet peering.

## What this module creates

- Hub VNet (`10.0.0.0/16` by default)
- Hub subnets:
  - `AzureFirewallSubnet`
  - DNS Resolver subnet
- Spoke VNet (`10.1.0.0/16` by default)
- Spoke subnets:
  - AKS subnet
  - Private Endpoint subnet
- NSGs and subnet associations
- Route tables and subnet associations
- VNet peering in both directions

## Usage

```hcl
module "networking" {
  source = "../../modules/networking"

  resource_group_name = "rg-example"
  location            = "australiaeast"
  tags = {
    environment = "sandbox"
    managed_by  = "terraform"
  }

  # Optional: route spoke outbound traffic via firewall private IP.
  # spoke_default_route_next_hop_ip = "10.0.0.4"
}
```

## Outputs

- `vnet_ids`
- `subnet_ids`
- `route_table_ids`
- `nsg_ids`
