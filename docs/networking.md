# Azure Networking Design: Hub-and-Spoke Implementation

## 1. Architecture Summary

The implementation uses a hub-and-spoke topology to separate shared network services from workload hosting. The hub virtual network hosts shared connectivity and security services, while the spoke virtual network hosts workload-aligned resources.

Implemented characteristics:

- clear separation of concerns between shared services and workloads
- controlled east-west and north-south traffic paths
- scalable growth for additional spokes without redesigning the core network

The Terraform configuration is delivered through a reusable networking module and consumed by the sandbox environment.

## 2. Address Space Strategy

The address plan is non-overlapping:

- Hub VNet: `10.0.0.0/16`
- Spoke VNet: `10.1.0.0/16`

Each VNet is allocated a `/16` range to accommodate subnet growth and future segmentation (for example, additional private endpoint ranges, ingress tiers, or shared platform services).

## 3. Subnet Design

### Hub VNet subnets

- `AzureFirewallSubnet`: `10.0.0.0/24`
- `snet-dns-resolver`: `10.0.1.0/24`

The dedicated `AzureFirewallSubnet` is reserved for Azure Firewall placement. The DNS Resolver subnet isolates name resolution infrastructure from workload subnets.

### Spoke VNet subnets

- `snet-aks`: `10.1.0.0/22`
- `snet-private-endpoint`: `10.1.4.0/24`

The AKS subnet is sized for node and pod network growth. The private endpoint subnet is separated from compute traffic.

The private endpoint subnet has private endpoint network policies disabled, which is required for private endpoint NIC placement.

## 4. Network Security Groups (NSGs)

The module creates and associates NSGs to the following subnets:

- `nsg-hub-dns-resolver` on `snet-dns-resolver`
- `nsg-spoke-aks` on `snet-aks`
- `nsg-spoke-private-endpoint` on `snet-private-endpoint`

This establishes subnet-level policy boundaries.

The `AzureFirewallSubnet` is not associated with an NSG in this implementation.

## 5. Route Tables and Traffic Steering

The module provisions route tables for:

- hub DNS Resolver subnet
- spoke AKS subnet
- spoke private endpoint subnet

An optional default route (`0.0.0.0/0`) to a virtual appliance is supported for spoke route tables. When the next-hop IP is provided, spoke subnet egress can be routed through Azure Firewall.

Current sandbox behavior:

- `spoke_default_route_next_hop_ip = null`
- no forced-tunnel default route is injected yet

No default route to a virtual appliance is currently configured in sandbox.

## 6. VNet Peering Configuration

Bidirectional peering is configured between hub and spoke:

- Hub-to-spoke peering
- Spoke-to-hub peering

Policy settings:

- virtual network access: enabled
- forwarded traffic: enabled
- gateway transit: disabled
- remote gateways: disabled

This enables direct private connectivity between hub and spoke with gateway transit disabled.

## 7. Azure Firewall Placement

Firewall placement is defined in the hub within `AzureFirewallSubnet`.

The networking module provisions the subnet boundary required for firewall deployment. Firewall resources can be deployed in a separate module.

This separates network scaffold deployment from firewall policy and rule deployment.

## 8. Private DNS Resolver Placement

Private DNS Resolver placement is defined in the hub model via the dedicated DNS resolver subnet (`snet-dns-resolver`).

Implemented DNS placement characteristics:

- standardizes private DNS behavior for all spoke workloads
- reduces duplicated DNS infrastructure in application VNets
- simplifies hybrid name resolution extension patterns

The networking module creates the subnet and attaches NSG/route table controls. Resolver endpoint resources can be added in a dedicated DNS module while reusing this subnet boundary.

