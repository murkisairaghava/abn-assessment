# Architecture Decision Records (ADR)

## ADR-001: Hub and Spoke Networking

### Context
The platform hosts multiple workloads with different trust boundaries and lifecycle cadences, including AKS, shared security controls, and data services. A flat virtual network design would increase blast radius, complicate route governance, and make central policy enforcement difficult across environments.

### Decision
Adopt a Hub and Spoke network topology.
- Hub VNet hosts shared services such as Azure Firewall, DNS forwarding/resolution components, and ingress/egress inspection points.
- Spoke VNets host workload-aligned resources (for example, private AKS and application dependencies).
- Connectivity is controlled through explicit peering, route tables, and centralized egress policy.

### Consequences
- Positive:
	- Stronger isolation between application domains and environments.
	- Centralized security controls and easier policy standardization.
	- Better scalability for future spokes without redesigning the core.
- Negative:
	- Additional routing and DNS complexity.
	- Higher operational overhead for peering, UDR, and governance lifecycle.

## ADR-002: Azure Firewall Instead of NAT Gateway

### Context
The workload requires controlled outbound connectivity with enterprise-grade policy enforcement, observability, and deterministic egress behavior. NAT Gateway provides scalable outbound SNAT but does not provide Layer 3-7 filtering or central rule governance required by security review.

### Decision
Use Azure Firewall as the primary egress control plane instead of NAT Gateway.
- Route outbound traffic from workload subnets to Azure Firewall via UDR.
- Implement application/network rules and threat intelligence filtering.
- Use firewall logging for security operations and auditability.

### Consequences
- Positive:
	- Rich policy enforcement and explicit allow-listing.
	- Centralized logging and investigation workflow for egress traffic.
	- Better alignment with regulated workload controls.
- Negative:
	- Higher cost than NAT-only architecture.
	- Requires careful SNAT capacity and rule management.

## ADR-003: Private AKS Cluster

### Context
The control plane and node communication for production workloads must avoid public exposure and align with least-exposure security posture. Public API endpoints increase attack surface and complicate inbound governance.

### Decision
Deploy AKS as a private cluster.
- AKS API server is reachable only through private networking.
- Cluster operations are performed from approved network locations (for example, self-hosted agent network, jump host, or connected management network).

### Consequences
- Positive:
	- Reduced external attack surface for Kubernetes control plane.
	- Improved compliance alignment for private-only management paths.
- Negative:
	- Operational tooling must run from private connectivity zones.
	- Additional setup for DNS resolution and management access patterns.

## ADR-004: Private Endpoints for Platform Dependencies

### Context
AKS workloads depend on services such as ACR, Key Vault, and Blob Storage. Public endpoints, even with firewall restrictions, still introduce internet-reachable surfaces and policy exceptions.

### Decision
Use Private Endpoints for Azure PaaS dependencies used by the platform.
- Provision private endpoints in workload-accessible VNets/subnets.
- Disable or tightly restrict public network access where supported.
- Integrate private endpoint DNS with private zones.

### Consequences
- Positive:
	- Service traffic remains on private network paths.
	- Reduces data exfiltration vectors via public endpoints.
	- Consistent policy model for internal service consumption.
- Negative:
	- Increased DNS and endpoint lifecycle complexity.
	- More resources to manage per service/environment.

## ADR-005: Azure CNI Overlay for AKS Networking

### Context
The cluster must support pod networking at scale while preserving manageable IP consumption in VNets with enterprise address constraints. Traditional Azure CNI pod IP allocation can accelerate subnet exhaustion in larger clusters.

### Decision
Use Azure CNI Overlay for AKS pod networking.
- Nodes receive VNet IPs; pods are assigned overlay CIDR addresses.
- Keep Kubernetes networking behavior while reducing direct VNet IP pressure.

### Consequences
- Positive:
	- Significantly improved IP scalability for pod growth.
	- Better fit for constrained enterprise RFC1918 space.
	- Retains Azure-integrated networking controls for nodes.
- Negative:
	- Requires architecture and operations familiarity with overlay model.
	- Some network troubleshooting paths become less intuitive than flat addressing.

## ADR-006: Workload Identity Instead of Kubernetes Secrets

### Context
Application access to Azure resources historically relied on credentials stored as Kubernetes secrets, creating rotation burden, leak risk, and weak secret governance posture.

### Decision
Use Microsoft Entra Workload Identity for pod-to-Azure authentication instead of storing static secrets in Kubernetes.
- Bind Kubernetes Service Accounts to User Assigned Managed Identities via federated identity credentials.
- Use short-lived OIDC token exchange for Azure access tokens.

### Consequences
- Positive:
	- Eliminates static cloud credentials from cluster secret store.
	- Improves rotation and breach containment through token lifetimes.
	- Clearer identity lineage and auditability in Azure logs.
- Negative:
	- Additional identity bootstrap steps (FIC, SA annotation, RBAC mapping).
	- Requires disciplined DNS/time/connectivity for token exchange reliability.

## ADR-007: Azure RBAC as Authorization Model

### Context
Resource authorization needs centralized policy, consistent least privilege, and auditable identity-to-permission mapping across AKS-integrated services.

### Decision
Use Azure RBAC as the primary authorization mechanism for Azure resource access.
- Assign least-privilege roles to managed identities at minimal required scope.
- Avoid broad Contributor assignments unless explicitly justified.

### Consequences
- Positive:
	- Unified authorization model across platform services.
	- Strong auditability and role governance through Azure controls.
	- Better separation of duties between platform and application teams.
- Negative:
	- Role assignment propagation delays can impact deployment timing.
	- Requires ongoing role hygiene and periodic access review.

## ADR-008: Helm Packaging for Kubernetes Deployments

### Context
Kubernetes deployments require repeatable packaging, versioning, and environment-specific configuration without duplicating manifests. Raw YAML management increases drift risk and reduces deployment consistency.

### Decision
Use Helm charts as the deployment packaging standard.
- Package application resources (Deployment, Service, ServiceAccount, ConfigMap).
- Parameterize operational settings (image, probes, resources, workload identity, namespace).
- Use `helm lint` and templating checks in CI before deployment.

### Consequences
- Positive:
	- Repeatable, versioned releases across environments.
	- Reduced manifest duplication through templating.
	- Strong CI/CD integration and validation workflow.
- Negative:
	- Template complexity can obscure rendered runtime state if poorly structured.
	- Requires chart discipline to prevent over-parameterization.

## ADR-009: Private DNS Zones for Name Resolution

### Context
Private endpoints and private AKS control-plane operations depend on deterministic private DNS resolution. Relying on public DNS for private resources leads to resolution failures and unpredictable network behavior.

### Decision
Adopt Private DNS Zones for private service resolution.
- Create and link required private zones to hub/spoke VNets.
- Ensure AKS nodes and management paths resolve private service FQDNs to private IPs.
- Govern DNS links and records as infrastructure code.

### Consequences
- Positive:
	- Reliable name resolution for private endpoints and private control-plane dependencies.
	- Supports private-only data path architecture with fewer exceptions.
	- Improves operational predictability in multi-VNet topologies.
- Negative:
	- Additional DNS governance and lifecycle management overhead.
	- Misconfiguration risk can cause broad connectivity impact across spokes.
