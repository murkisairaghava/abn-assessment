# AKS Platform Architecture Review

## 1. Scope

This document describes the implemented AKS platform architecture for the sandbox environment, with focus on private control-plane access, identity controls, networking model, and operational observability.

Covered areas:

- private AKS architecture
- Azure CNI Overlay
- Azure RBAC
- OIDC issuer
- workload identity
- managed identities
- Log Analytics integration

## 2. Private AKS Architecture

The AKS cluster is configured as a private cluster:

- private control plane enabled
- public FQDN for the private cluster disabled
- local admin account disabled

Control plane access occurs through private networking paths and associated private DNS resolution. The node pool is deployed into the spoke AKS subnet, with the cluster integrated into the existing hub-spoke network topology.

Operationally, the design separates:

- workload node placement in the spoke AKS subnet
- private endpoint-based PaaS access in a dedicated spoke private endpoint subnet
- centralized shared services in hub (for example, DNS and security services)

## 3. Azure CNI Overlay Networking Model

The cluster uses Azure CNI with overlay mode:

- `network_plugin = azure`
- `network_plugin_mode = overlay`
- `network_policy = azure`

Addressing behavior:

- pod IPs are allocated from the overlay pod CIDR
- nodes remain attached to the VNet subnet
- service IPs are allocated from the service CIDR

This model provides Kubernetes-native pod scale behavior while keeping VNet IP utilization focused on node and infrastructure interfaces.

## 4. Azure RBAC and Cluster Authorization

Authorization is implemented with managed Azure AD integration and Azure RBAC enabled:

- Kubernetes RBAC enabled
- Azure AD RBAC integration block configured
- Azure RBAC authorization enabled

This setup provides centralized role assignment and governance through Azure role definitions, reducing reliance on static in-cluster credential distribution.

## 5. OIDC Issuer and Workload Identity

The cluster has both OIDC issuer and workload identity enabled:

- OIDC issuer enabled
- workload identity enabled

This enables federated identity for Kubernetes service accounts to exchange OIDC tokens for Azure AD tokens without storing long-lived secrets in pods. It supports identity-first access patterns to platform services such as Key Vault, Storage, and ACR.

## 6. Managed Identity Design

The cluster is configured with a user-assigned managed identity (UAMI) for cluster identity:

- UAMI resource created in the target resource group
- AKS identity type set to `UserAssigned`
- UAMI attached to the cluster identity block

In addition, AKS provides kubelet identity for node-level operations. This separation supports clear identity boundaries between control-plane level operations and node/runtime interactions.

## 7. Node Pool Configuration

The platform uses a system node pool only, aligned to baseline platform footprint requirements:

- VM size: `Standard_D4s_v5`
- VMSS node pool type
- autoscaling enabled
- minimum node count: 1
- maximum node count: 3
- only critical addons enabled on system pool

This establishes a constrained but elastic capacity profile suitable for sandbox and platform baseline validation.

## 8. Log Analytics Integration

Cluster observability is enabled through OMS agent integration with an existing Log Analytics workspace:

- workspace ID passed from the monitoring module output
- AKS sends platform and workload telemetry to centralized workspace

This supports operational scenarios including health monitoring, query-based diagnostics, and centralized retention controls.

## 9. Versioning and Upgrade Posture

Cluster version selection is driven from available stable Kubernetes versions in the target Azure region (preview versions excluded), with automatic patch upgrade channel enabled.

This balances:

- current stable baseline adoption
- controlled security patch movement
- reduced manual version lifecycle overhead

## 10. Architecture Positioning Summary

The implemented AKS platform configuration aligns to a private-first, identity-first architecture pattern:

- private control-plane exposure model
- overlay networking for pod scale and subnet efficiency
- centralized Azure RBAC governance
- OIDC and workload identity for secretless service authentication
- managed identity-driven control-plane and node interactions
- centralized Log Analytics integration for observability

This provides a strong baseline for production-oriented Azure platform assessments while preserving clear extension points for policy hardening, multi-node pool strategies, and advanced security controls.
