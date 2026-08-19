# Private Services Connectivity Architecture

## 1. Purpose and Scope

This document describes the private connectivity pattern implemented for Azure Key Vault, Azure Blob Storage, and Azure Container Registry (ACR). The design objective is to provide private-only service access from workload networks while enforcing network-level and service-level security controls.

Covered components:

- Azure Key Vault private connectivity
- Azure Blob Storage private connectivity
- Azure Container Registry private connectivity
- Private Endpoint architecture
- Private DNS zone integration
- Rationale for disabling public network access

## 2. Architecture Summary

The implementation uses Azure Private Link with dedicated Private Endpoints in the spoke private endpoint subnet. DNS resolution for private service FQDNs is provided through Azure Private DNS zones linked to both hub and spoke VNets.

High-level characteristics:

- service access is resolved to private IP addresses
- endpoint NICs are placed in a dedicated subnet boundary
- all three PaaS services have public network access disabled
- DNS zones are centrally managed and linked to all supplied VNets

## 3. Private Endpoint Architecture

Private Endpoints are created per service and mapped to service-specific subresources:

- Key Vault: `vault`
- Storage Account: `blob`
- ACR: `registry`

Each private endpoint:

- deploys into the provided private endpoint subnet
- creates a private service connection to the target resource
- attaches a private DNS zone group referencing an existing private DNS zone

This pattern standardizes service onboarding and ensures that private endpoint deployment remains consistent across services.

## 4. Private DNS Zone Integration

The private DNS module creates and manages these zones:

- `privatelink.vaultcore.azure.net`
- `privatelink.blob.core.windows.net`
- `privatelink.azurecr.io`

Integration model:

- every zone is linked to all supplied VNets
- current environment links both hub and spoke VNets
- VNet link registration is disabled

Service modules consume the relevant DNS zone ID and bind it to the corresponding private endpoint zone group. This ensures DNS records for private endpoints are resolved within linked VNets.

## 5. Azure Key Vault Private Connectivity

Key Vault private connectivity is implemented with the following controls:

- private endpoint in the spoke private endpoint subnet
- private DNS integration with `privatelink.vaultcore.azure.net`
- public network access disabled
- RBAC authorization enabled
- purge protection enabled
- soft delete retention enabled
- network ACL default action set to deny

Resulting access posture:

- Key Vault data-plane access is reachable through private endpoint paths only
- DNS name resolution returns private endpoint addresses for linked VNets

## 6. Azure Blob Storage Private Connectivity

Blob private connectivity is implemented through a Storage Account with private endpoint integration:

- private endpoint in the spoke private endpoint subnet
- private DNS integration with `privatelink.blob.core.windows.net`
- endpoint limited to Blob subresource (`blob`)
- public network access disabled
- minimum TLS version set to `TLS1_2`
- infrastructure encryption enabled
- storage network rules default deny

Resulting access posture:

- Blob service traffic is resolved and routed over private endpoint connectivity
- public endpoint data access is not used for workload connectivity

## 7. Azure Container Registry Private Connectivity

ACR private connectivity is implemented as follows:

- Premium SKU registry
- admin user disabled
- anonymous pull disabled
- public network access disabled
- private endpoint in the spoke private endpoint subnet
- private DNS integration with `privatelink.azurecr.io`

Resulting access posture:

- registry access is resolved to private endpoint addresses in linked VNets
- administrative and image access patterns align to private network boundaries

## 8. Why Public Network Access Is Disabled

Public network access is disabled on Key Vault, Storage Account, and ACR to enforce a private-first service perimeter.

Architecture rationale:

- reduces exposure to internet-reachable endpoints
- enforces deterministic internal routing through private endpoints
- centralizes name resolution through private DNS controls
- aligns service connectivity with hub-spoke segmentation and subnet policy boundaries

Security impact:

- requests must originate from network locations with private endpoint reachability
- service access policy becomes coupled to both identity and network placement

## 9. End-to-End Connectivity Sequence (Conceptual)

For each service request from workloads in the spoke VNet:

1. Client resolves service FQDN using private DNS in linked VNets.
2. DNS returns private endpoint IP address in the private endpoint subnet.
3. Client establishes connection to the private endpoint NIC.
4. Azure Private Link forwards traffic to the target PaaS service.
5. Service processes request under its configured identity, authorization, and network policies.

This sequence is common across Key Vault, Blob Storage, and ACR in the current implementation.
