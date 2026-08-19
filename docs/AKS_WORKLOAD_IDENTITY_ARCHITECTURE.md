# Azure AKS Workload Identity Architecture

**Document Type:** Architecture Review  
**Date:** 2026-08-18  
**Classification:** Technical Design  
**Audience:** Infrastructure Leadership, Security Review Board

---

## Executive Summary

This document provides a comprehensive architectural analysis of the Microsoft Entra Workload Identity integration with Azure Kubernetes Service (AKS). The solution eliminates the need for static credentials (connection strings, storage keys) by leveraging Azure's federated identity model, enabling Kubernetes workloads to authenticate to Azure resources using OIDC-based token exchange.

**Key Design Principle:** Zero-Secret Authentication via OIDC Federation

---

## Architecture Overview

### High-Level Authentication Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         AKS Cluster (Private)                   │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────┐                              │
│  │   shows-api Pod              │                              │
│  ├──────────────────────────────┤                              │
│  │ • Container: FastAPI (8080)  │                              │
│  │ • UID: 10001 (non-root)      │                              │
│  │ • FSGroup: 10001             │                              │
│  └──────────┬───────────────────┘                              │
│             │ 1. Request Token                                 │
│             ▼                                                   │
│  ┌──────────────────────────────┐                              │
│  │  Kubernetes Service Account  │                              │
│  ├──────────────────────────────┤                              │
│  │ Name: shows-api-sa           │                              │
│  │ Namespace: production        │                              │
│  │ aud: api://AzureADTokenExch  │                              │
│  └──────────┬───────────────────┘                              │
│             │ 2. Mount Projected Token                         │
│             ▼                                                   │
│  ┌──────────────────────────────────────────┐                  │
│  │ Projected Service Account Token Volume  │                  │
│  ├──────────────────────────────────────────┤                  │
│  │ /var/run/secrets/azure/tokens/token      │                  │
│  │ Expiry: 60 minutes (auto-rotated)       │                  │
│  │ Format: JWT (OIDC-compliant)            │                  │
│  └──────────┬───────────────────────────────┘                  │
│             │ 3. Get OIDC Token                                │
│             ▼                                                   │
│  ┌──────────────────────────────────────────┐                  │
│  │      Workload Identity Mutating          │                  │
│  │         Webhook (system/ns)              │                  │
│  ├──────────────────────────────────────────┤                  │
│  │ Patches pod with:                        │                  │
│  │ • Service Account Token Mount            │                  │
│  │ • Label: azure.workload.identity/use     │                  │
│  │ • Environment: AZURE_FEDERATED_TOKEN_    │                  │
│  │              FILE + AZURE_CLIENT_ID      │                  │
│  └──────────┬───────────────────────────────┘                  │
│             │ 4. Request Access Token                          │
│             ▼                                                   │
│  ┌──────────────────────────────────────────┐                  │
│  │    AKS OIDC Issuer (Public Endpoint)     │                  │
│  ├──────────────────────────────────────────┤                  │
│  │ https://<region>.oic.prod-aks.azure.    │                  │
│  │         com/<tenant>/<cluster>/          │                  │
│  │ • Validates Kubernetes credentials      │                  │
│  │ • Issues OIDC Token                      │                  │
│  │ • aud: AZURE_CLIENT_ID                   │                  │
│  └──────────┬───────────────────────────────┘                  │
│             │ 5. Request Token Exchange                        │
└─────────────┼──────────────────────────────────────────────────┘
              │ HTTPS/Mutual TLS
              ▼
┌─────────────────────────────────────────────────────────────────┐
│              Microsoft Entra ID (Azure AD)                      │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────────────────┐                              │
│  │  Federated Identity          │                              │
│  │    Credential (FIC)          │                              │
│  ├──────────────────────────────┤                              │
│  │ • Issuer: AKS OIDC URL       │                              │
│  │ • Subject: ServiceAccount/   │                              │
│  │           namespace/name     │                              │
│  │ • Audience: api://client-id  │                              │
│  │ • Status: Active             │                              │
│  └──────────┬───────────────────┘                              │
│             │ Validates Token                                   │
│             ▼                                                   │
│  ┌──────────────────────────────┐                              │
│  │  User Assigned Managed       │                              │
│  │      Identity (UAMI)         │                              │
│  ├──────────────────────────────┤                              │
│  │ • Type: UserAssignedIdentity │                              │
│  │ • Client ID: <guid>          │                              │
│  │ • Tenant ID: <guid>          │                              │
│  │ • Status: Active             │                              │
│  └──────────┬───────────────────┘                              │
│             │ 6. Issue Access Token                            │
│             ▼                                                   │
│  ┌──────────────────────────────┐                              │
│  │  Access Token (OAuth 2.0)    │                              │
│  ├──────────────────────────────┤                              │
│  │ • Scope: Azure Resource      │                              │
│  │ • Expiry: 3600 seconds       │                              │
│  │ • Claims: OID, Principal     │                              │
│  └──────────┬───────────────────┘                              │
│             │ Return to Pod
└─────────────┼──────────────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────────────┐
│              Azure Resource Managers                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────────┐    ┌──────────────────┐                  │
│  │  Azure Key Vault │    │ Blob Storage     │                  │
│  ├──────────────────┤    ├──────────────────┤                  │
│  │ • RBAC: UAMI     │    │ • RBAC: UAMI     │                  │
│  │ • Authenticate   │    │ • Authenticate   │                  │
│  │ • Grant Access   │    │ • Grant Access   │                  │
│  └──────────────────┘    └──────────────────┘                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Component Architecture

### 1. AKS OIDC Issuer

**Definition:** The Kubernetes-native OpenID Connect (OIDC) provider built into AKS that acts as a trust intermediary between Kubernetes ServiceAccounts and Azure Entra ID.

**Technical Specifications:**

| Property | Value | Purpose |
|----------|-------|---------|
| **Type** | OIDC Provider | Standards-based identity protocol |
| **Endpoint** | `https://<region>.oic.prod-aks.azure.com/<tenant>/<cluster>/` | Public discovery endpoint |
| **Protocol** | OpenID Connect 1.0 | RFC 8414 compliant |
| **Key Discovery** | JWKS (JSON Web Key Set) | Public key rotation |
| **Token Format** | JWT (JSON Web Token) | RFC 7519 compliant |
| **Signature Algorithm** | RS256 (RSA SHA-256) | Industry standard |
| **Token Expiry** | 60 minutes | Automatic rotation by kubelet |
| **Audience (aud)** | `api://AzureADTokenExchange` | Explicit token audience |

**Operational Characteristics:**

- ✅ No credentials stored in pod
- ✅ Tokens automatically rotated every 60 minutes
- ✅ Kubernetes kubelet projects token into pod filesystem
- ✅ Token placed at: `/var/run/secrets/azure/tokens/token`
- ✅ Read-only to pod (security hardening)

**Threat Model Mitigation:**

- Token scope limited to specific ServiceAccount
- Namespace isolation enforced
- Token lifetime bounded (60 min)
- Signature validation prevents tampering
- Issuer validation prevents token hijacking

---

### 2. Microsoft Entra Workload Identity

**Definition:** Azure's managed identity federation model that enables Kubernetes workloads to acquire Azure access tokens without managing static credentials.

**Authentication Flow (RFC 8693 - Token Exchange):**

```
Pod Application
    │
    ├─ Reads Kubernetes OIDC Token
    │  (from /var/run/secrets/azure/tokens/token)
    │
    ├─ Calls: POST /oauth2/v2.0/token
    │  With: 
    │    assertion=<jwt>
    │    grant_type=urn:ietf:params:oauth:grant-type:token-exchange
    │    subject_token_type=urn:ietf:params:oauth:token-type:jwt
    │    client_id=<app-id>
    │
    └─ Receives: Access Token (OAuth 2.0)
       Scope: https://management.azure.com/.default
```

**Key Components:**

1. **ServiceAccount (Kubernetes):**
   - Kubernetes-managed identity within cluster
   - Links pod to Azure Entra identity via federated credential
   - Annotation: `azure.workload.identity/client-id: <GUID>`
   - Label on pod: `azure.workload.identity/use: "true"`

2. **Federated Identity Credential (Azure):**
   - One-way trust relationship (not a shared secret)
   - Validates Kubernetes OIDC tokens
   - Mapping: OIDC Token Claims → Azure Identity
   - Immutable once created (audit trail)

3. **User Assigned Managed Identity (Azure):**
   - Azure resource with unique identity
   - No credentials to manage
   - Can be assigned RBAC roles
   - Lifecycle independent of pod

**Security Properties:**

- ✅ No secret ever transmitted over network
- ✅ Token claims cryptographically signed
- ✅ Issuer identity validated via JWKS
- ✅ Subject claim immutable (pod identity)
- ✅ Audience (aud) claim prevents token reuse

---

### 3. User Assigned Managed Identity (UAMI)

**Definition:** An Azure AD application object that represents the workload and holds no secrets. RBAC roles assigned to this identity grant resource access.

**Architectural Role:**

```
                    Federated Trust
                         │
        ┌────────────────┴────────────────┐
        │                                 │
        ▼                                 ▼
  Kubernetes SA                    Entra App Registration
  (shows-api-sa)        ◄───────►    (UAMI)
  - Namespace: prod                - Client ID: <guid>
  - Issuer URL: <OIDC>            - Tenant ID: <guid>
  - Subject: /service            - No secret
    accounts/prod/shows-api-sa    - RBAC-based
```

**Identity Properties:**

| Property | Details |
|----------|---------|
| **Type** | User Assigned Managed Identity |
| **Lifecycle** | Independent of pod/cluster |
| **Credentials** | None (managed by Azure) |
| **Scope** | Subscription-level resource |
| **Cost** | No additional charge |
| **Audit Trail** | Full Azure Activity Log coverage |

**RBAC Role Assignment Example:**

```azure-cli
az role assignment create \
  --role "Storage Blob Data Reader" \
  --assignee-object-id <UAMI-principal-id> \
  --scope /subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Storage/storageAccounts/<account>/blobServices/default/containers/<container>
```

**Result:** UAMI can now authenticate to Blob Storage and read blobs within specified container only.

---

### 4. Federated Identity Credential (FIC)

**Definition:** A cryptographic trust relationship that links a Kubernetes ServiceAccount to a Managed Identity by validating OIDC token claims.

**Trust Establishment:**

```
FIC Configuration:
┌────────────────────────────────────────────────────────┐
│ Issuer:   https://<region>.oic.prod-aks.azure.com/    │ ← OIDC URL
│          <tenant>/<cluster>/                          │
├────────────────────────────────────────────────────────┤
│ Subject:  system:serviceaccount:production:shows-api-sa│ ← k8s identity
├────────────────────────────────────────────────────────┤
│ Audience: api://AzureADTokenExchange                   │ ← Token aud
└────────────────────────────────────────────────────────┘

When pod requests token:
1. Kubernetes signs JWT with cluster key
2. aud claim = "api://AzureADTokenExchange"
3. sub claim = "system:serviceaccount:prod:shows-api-sa"
4. iss claim = "https://<region>.oic.prod-aks.azure.com/..."

Entra validates:
✓ iss matches FIC issuer (prevents spoofing)
✓ sub matches FIC subject (prevents lateral movement)
✓ aud matches FIC audience (prevents token reuse)
✓ Signature valid via JWKS (prevents tampering)

Result: Access token issued to UAMI
```

**Validation Properties:**

| Check | Purpose | Prevents |
|-------|---------|----------|
| Issuer (iss) | Authenticates OIDC provider | OIDC provider impersonation |
| Subject (sub) | Binds to specific ServiceAccount | Cross-namespace pod hijacking |
| Audience (aud) | Ensures token reuse protection | Token replay attacks |
| Signature | Cryptographic proof | Token tampering |
| Expiry | Time-bound token | Token lifetime abuse |

---

### 5. Key Vault Access Flow

**Scenario:** Pod needs to access secrets in Azure Key Vault

**Authentication Sequence:**

```
Step 1: Pod requests secret
────────────────────────────
App Code (shows-api)
   │
   └─ DefaultAzureCredential()
      └─ WorkloadIdentityCredential
         └─ Reads: AZURE_FEDERATED_TOKEN_FILE
         └─ Reads: AZURE_CLIENT_ID
         └─ Reads: AZURE_TENANT_ID

Step 2: Token exchange with Entra
──────────────────────────────────
POST /oauth2/v2.0/token
Body:
  grant_type=urn:ietf:params:oauth:grant-type:token-exchange
  assertion=<k8s-jwt>
  subject_token_type=urn:ietf:params:oauth:token-type:jwt
  client_id=<uami-client-id>
  audience=api://AzureADTokenExchange

Response:
  access_token=<oauth-token>
  expires_in=3600
  token_type=Bearer

Step 3: Access Key Vault
────────────────────────
GET /secrets/<secret-name>?api-version=7.4
Authorization: Bearer <access-token>

Key Vault checks RBAC:
✓ Token issued to UAMI
✓ UAMI has "Key Vault Secrets User" role
✓ Resource within allowed scope

Response:
  Secret value returned (encrypted in flight)

Step 4: Application uses secret
────────────────────────────────
App → Blob Storage (with connection string)
```

**RBAC Configuration (Code Example):**

```terraform
# Terraform: Assign secret access to pod identity
resource "azurerm_key_vault_access_policy" "pod_access" {
  key_vault_id = azurerm_key_vault.example.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.shows_api.principal_id

  secret_permissions = [
    "Get",
    "List"
  ]
}

# Result: UAMI can read secrets
```

**Security Properties:**

- ✅ Access token scoped to Vault + resource group
- ✅ RBAC controls specific secret access
- ✅ No storage keys in environment
- ✅ Audit: Every access logged in Key Vault audit trail
- ✅ Token lifecycle: 60 minutes (automatic refresh)

---

### 6. Blob Storage Access Flow

**Scenario:** Pod needs to read/write blobs in Azure Storage Account

**Authentication Sequence:**

```
Step 1: Application initializes BlobStorageCache
─────────────────────────────────────────────────
from azure.storage.blob import BlobServiceClient
from azure.identity import DefaultAzureCredential

credential = DefaultAzureCredential()
client = BlobServiceClient(
    account_url="https://mystg.blob.core.windows.net",
    credential=credential
)

Step 2: Credentials attempt order
────────────────────────────────
DefaultAzureCredential tries:
  1. Environment credentials (not set)
  2. Workload Identity ✓ (FOUND - uses this)
  3. Managed Identity (cluster MSI)
  4. Azure CLI credentials
  5. Visual Studio credentials

Step 3: Workload Identity token flow
──────────────────────────────────
WorkloadIdentityCredential reads:
  • AZURE_FEDERATED_TOKEN_FILE=/var/run/secrets/azure/tokens/token
  • AZURE_CLIENT_ID=<uami-guid>
  • AZURE_TENANT_ID=<tenant-guid>

Calls token endpoint:
  POST https://login.microsoftonline.com/<tenant>/oauth2/v2.0/token
  
With scopes:
  https://storage.azure.com/.default

Step 4: Access Blob Storage
──────────────────────────
GET /shows_girls.json
Authorization: Bearer <access-token>
x-ms-version: 2021-08-06

Blob Service checks:
  ✓ Access token valid
  ✓ Issuer is Entra
  ✓ Token scope includes storage.azure.com
  ✓ RBAC: UAMI has "Storage Blob Data Reader" role
  ✓ Container: cache (RBAC scope)

Response:
  Status: 200 OK
  Body: Cache JSON (if TTL valid)
  Headers: x-ms-blob-type: BlockBlob
```

**RBAC Configuration (Terraform Example):**

```terraform
# Assign Blob Storage Reader role to UAMI
resource "azurerm_role_assignment" "blob_access" {
  scope              = "${azurerm_storage_account.cache.id}/blobServices/default/containers/cache"
  role_definition_name = "Storage Blob Data Reader"
  principal_id       = azurerm_user_assigned_identity.shows_api.principal_id
}

# Result: UAMI can read blobs in cache container only
```

**Caching Layer Integration:**

```python
class BlobStorageCache:
    def __init__(self, config: BlobStorageConfig):
        # Workload Identity automatically handles authentication
        self._credential = DefaultAzureCredential()
        self._blob_service_client = BlobServiceClient(
            account_url=config.storage_account_url,
            credential=self._credential,
        )
        # No connection strings, no storage keys in code/env
```

**Security Properties:**

- ✅ No storage account keys in pod
- ✅ Token scope limited to Storage API
- ✅ RBAC controls container + blob level
- ✅ Access audited via Storage Analytics logs
- ✅ Token automatically rotated (60 min)
- ✅ Cross-tenant access prevented

---

## Complete Authentication Flow

### Pod Identity to Azure Resource Authorization

**Detailed Step-by-Step Sequence:**

#### Phase 1: Pod Initialization (Cluster Control Plane)

```
1. User deploys Helm chart with ServiceAccount
   helm install shows-api helm/shows-api \
     --set workloadIdentity.clientId="<guid>"

2. Admission Controller (Workload Identity Webhook) intercepts:
   • Validates pod spec
   • Checks azure.workload.identity/use label
   • Patches pod spec:
     - Mount ServiceAccount token projection
     - Add environment: AZURE_CLIENT_ID, AZURE_TENANT_ID
     - Add environment: AZURE_FEDERATED_TOKEN_FILE

3. Kubelet projects ServiceAccount token
   • Creates JWT with:
     - aud: "api://AzureADTokenExchange"
     - sub: "system:serviceaccount:prod:shows-api-sa"
     - iss: "https://<region>.oic.prod-aks.azure.com/<tenant>/<cluster>/"
   • Mounts at: /var/run/secrets/azure/tokens/token
   • Expires: 60 minutes
   • Auto-rotated by kubelet before expiry
```

#### Phase 2: Application Runtime (Pod Execution)

```
4. shows-api starts with FastAPI
   • Imports: from azure.storage.blob import BlobServiceClient
   • Imports: from azure.identity import DefaultAzureCredential
   • No credentials hardcoded or in env (secure by default)

5. BlobStorageCache initialization (on app startup)
   credential = DefaultAzureCredential()
   client = BlobServiceClient(
       account_url="https://mystg.blob.core.windows.net",
       credential=credential
   )
   
   DefaultAzureCredential tries chain:
   • EnvironmentCredential: No env vars set (by design) ✗
   • WorkloadIdentityCredential: Finds AZURE_FEDERATED_TOKEN_FILE ✓
     └─ Returns credential handler for token exchange

6. HTTP request to Blob Storage (e.g., GET /cache/shows_girls.json)
   • Azure SDK detects credential type: WorkloadIdentity
   • Reads token from filesystem
   • Prepares request with Authorization header
```

#### Phase 3: Token Exchange (Entra Token Endpoint)

```
7. Pod calls: POST https://login.microsoftonline.com/<tenant>/oauth2/v2.0/token
   
   Request Body:
   {
     "grant_type": "urn:ietf:params:oauth:grant-type:token-exchange",
     "subject_token": "<jwt-from-kubernetes>",
     "subject_token_type": "urn:ietf:params:oauth:token-type:jwt",
     "client_id": "<uami-client-id>",
     "audience": "https://storage.azure.com"
   }
   
   Headers:
   {
     "Content-Type": "application/x-www-form-urlencoded",
     "User-Agent": "azsdk-python-identity/1.16.1 ..."
   }

8. Entra Token Endpoint validation:
   
   a) Signature Verification
      • Fetch OIDC issuer's JWKS endpoint
      • Retrieve RS256 public key
      • Verify JWT signature matches cluster's private key
      • Prevents tampering and spoofing
   
   b) Claims Validation
      • iss (Issuer) = "https://<region>.oic.prod-aks.azure.com/..."
        └─ Must match Federated Credential issuer
      • sub (Subject) = "system:serviceaccount:prod:shows-api-sa"
        └─ Must match Federated Credential subject
      • aud (Audience) = "api://AzureADTokenExchange"
        └─ Must match Federated Credential audience
      • exp (Expiration) > current_time
        └─ Token must not be expired
   
   c) Federated Credential Lookup
      • Search Azure AD for FIC with:
        - Issuer matching JWT iss claim
        - Subject matching JWT sub claim
        - Audience matching JWT aud claim
      • Retrieve linked UAMI (User Assigned Managed Identity)
   
   d) Token Issuance
      • Create OAuth 2.0 Access Token:
        - aud: "https://storage.azure.com" (from request)
        - sub: "<uami-object-id>"
        - oid: "<uami-object-id>"
        - iss: "https://login.microsoftonline.com/<tenant>/v2.0"
        - exp: current_time + 3600 seconds
        - iat: current_time
      • Sign with Entra's private key (RS256)
      • Return to pod

9. Pod receives Access Token
   {
     "access_token": "eyJ0eXAiOiJKV1QiLCJhbGc...",
     "token_type": "Bearer",
     "expires_in": 3600,
     "scope": "https://storage.azure.com/.default"
   }
```

#### Phase 4: Azure Resource Access (Blob Storage)

```
10. Pod calls Azure Blob Storage API:
    
    GET https://mystg.blob.core.windows.net/cache/shows_girls.json
    
    Headers:
    {
      "Authorization": "Bearer <access-token>",
      "x-ms-version": "2021-08-06",
      "User-Agent": "Azure-Storage/12.23.1 ..."
    }

11. Blob Storage validates request:
    
    a) Access Token Validation
       • Fetch Azure AD's JWKS (cached)
       • Verify RS256 signature
       • Confirm issuer: https://login.microsoftonline.com/
       • Confirm aud: https://storage.azure.com/
       • Confirm not expired
    
    b) RBAC Evaluation
       • Extract subject (OID) from token = UAMI object ID
       • Query Azure RBAC store for role assignments:
         - Resource: /subscriptions/.../storageAccounts/mystg/
                     blobServices/default/containers/cache
         - Principal: UAMI
         - Role: "Storage Blob Data Reader" ✓
       • Verify scope includes requested operation (READ)
    
    c) Audit Logging
       • Log: Principal (UAMI), Operation (READ), Resource (blob), Result (OK)
       • Timestamp, Client IP, Request ID recorded

12. Response to Pod
    
    Status: 200 OK
    Headers:
    {
      "x-ms-blob-type": "BlockBlob",
      "x-ms-blob-content-length": "1024",
      "Last-Modified": "2026-08-18T10:30:00Z"
    }
    Body: JSON cache data
    
    Pod receives data, application uses in response

13. Token Refresh (Automatic)
    • SDK caches access token until 5 min before expiry
    • At ~55 min: Automatically requests new token (step 7-9)
    • No application code change needed
    • No service interruption
```

---

## Security Model Analysis

### Threat Model & Mitigations

| Threat | Attack Vector | Mitigation |
|--------|---|---|
| **Token Theft** | Pod compromised, token file copied | Token file: read-only, owned by `azure-workload-identity`, pod runs as UID 10001 |
| **Token Forgery** | Attacker creates fake JWT | Entra validates RS256 signature with AKS cluster's public key |
| **Token Reuse** | Token used for different resource | aud (audience) claim tied to specific Azure service |
| **Cross-Namespace Hijacking** | Pod impersonates another namespace | sub (subject) claim includes namespace + SA name |
| **OIDC Issuer Spoofing** | Attacker impersonates OIDC provider | iss (issuer) claim validated against registered OIDC URL |
| **Key Vault Secret Exposure** | Unencrypted secret in pod memory | (a) Secret stored at rest encrypted; (b) TLS in flight; (c) RBAC scoped |
| **Blob Storage Access Abuse** | Read access to unintended container | RBAC role assignment scoped to specific container |
| **Long-lived Credentials** | Stale keys compromise security | Tokens auto-rotate every 60 minutes |
| **Audit Trail Loss** | Unauthorized access not logged | All operations logged to Azure Activity Log + Storage Analytics |

### Zero Trust Properties

✅ **Never Trust, Always Verify:**
- No implicit trust between pod and resource
- Every request requires valid, signed token
- RBAC enforces principle of least privilege
- Audit trail for compliance/investigation

✅ **Assume Breach:**
- If pod compromised, attacker can only use issued tokens
- Token lifetime limited (60 min)
- Token scope limited (specific service/resource)
- RBAC restricts operations (read-only if assigned)

✅ **Cryptographic Proof:**
- JWT signature prevents tampering
- Issuer validation prevents impersonation
- Subject claim prevents lateral movement

---

## Deployment Considerations

### Prerequisites

| Component | Requirement |
|-----------|---|
| **AKS** | Version 1.20+; OIDC Issuer enabled |
| **Workload Identity** | Azure CLI extension or Portal provisioning |
| **UAMI** | Created in same subscription |
| **Federated Credential** | Configured with correct issuer/subject/audience |
| **RBAC** | Role assignment on target resource |
| **Helm Chart** | Labels + annotations configured |

### Helm Integration

```yaml
# values.yaml
workloadIdentity:
  enabled: true
  clientId: ""  # Pass via --set

# templates/serviceaccount.yaml
{{- if .Values.workloadIdentity.enabled }}
metadata:
  annotations:
    azure.workload.identity/client-id: {{ .Values.workloadIdentity.clientId | quote }}
{{- end }}

# templates/deployment.yaml
metadata:
  labels:
    azure.workload.identity/use: "true"  # Pod label for webhook
```

### Deployment Command

```bash
helm install shows-api helm/shows-api \
  --namespace production \
  --set image.tag=2.0.0 \
  --set workloadIdentity.clientId="12345678-1234-1234-1234-123456789012" \
  --set config.BLOB_STORAGE_ENABLED=true \
  --set config.STORAGE_ACCOUNT_URL=https://mystg.blob.core.windows.net
```

### Infrastructure as Code (Terraform)

```hcl
# Create User Assigned Managed Identity
resource "azurerm_user_assigned_identity" "shows_api" {
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  name                = "shows-api-identity"
}

# Create Federated Identity Credential
resource "azurerm_federated_identity_credential" "shows_api" {
  resource_group_name = azurerm_resource_group.main.name
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.aks.oidc_issuer_url
  parent_id           = azurerm_user_assigned_identity.shows_api.id
  name                = "k8s-shows-api-sa"
  subject             = "system:serviceaccount:production:shows-api-sa"
}

# Assign RBAC for Blob Storage access
resource "azurerm_role_assignment" "blob_access" {
  scope              = "${azurerm_storage_account.cache.id}/blobServices/default/containers/cache"
  role_definition_name = "Storage Blob Data Reader"
  principal_id       = azurerm_user_assigned_identity.shows_api.principal_id
}

# Assign RBAC for Key Vault access (if needed)
resource "azurerm_key_vault_access_policy" "shows_api" {
  key_vault_id = azurerm_key_vault.main.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_user_assigned_identity.shows_api.principal_id
  
  secret_permissions = ["Get", "List"]
}
```

---

## Operational Guidance

### Troubleshooting Authentication Failures

**Scenario: Pod fails to authenticate to Blob Storage**

| Symptom | Root Cause | Resolution |
|---------|-----------|---|
| "AADSTS700016: Application not found in directory" | UAMI does not exist or was deleted | Verify UAMI in same subscription; recreate if needed |
| "AADSTS700065: Application returned by the server does not match the application" | FIC subject/issuer/audience mismatch | Validate FIC claims match pod identity and OIDC issuer |
| "403 Forbidden on Blob Storage" | RBAC role assignment missing/incorrect | Verify role assignment on container scope; check principal ID |
| "Token exchange failed" | Entra reject JWT | Check OIDC issuer URL; verify cluster issuer enabled |
| "Permission denied: do not have permission" | Wrong RBAC role | Assign "Storage Blob Data Reader" (not "Contributor"); scope to container |

**Diagnostic Commands:**

```bash
# Verify pod has token
kubectl exec -it deployment/shows-api -n production -- \
  cat /var/run/secrets/azure/tokens/token | head -c 100

# Check pod environment
kubectl exec -it deployment/shows-api -n production -- \
  env | grep AZURE

# Test Blob access from pod
kubectl exec -it deployment/shows-api -n production -- \
  python3 -c "
from azure.storage.blob import BlobServiceClient
from azure.identity import DefaultAzureCredential
cred = DefaultAzureCredential()
print('✓ Credentials initialized')
client = BlobServiceClient(
    account_url='https://mystg.blob.core.windows.net',
    credential=cred
)
blobs = client.get_container_client('cache').list_blobs()
print(f'✓ Listed blobs: {list(blobs)}')
  "

# Check UAMI in Entra
az identity show \
  --resource-group <rg> \
  --name shows-api-identity

# Verify FIC
az identity federated-credential list \
  --resource-group <rg> \
  --identity-name shows-api-identity

# Test token exchange locally
OIDC_TOKEN=$(curl -s --header 'Metadata:true' \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2021-02-01&resource=api%3A%2F%2FAzureADTokenExchange" \
  | jq -r '.access_token')
# (Only works from pod with Workload Identity webhook)
```

### Monitoring & Observability

**Key Metrics to Monitor:**

| Metric | Source | Alert Threshold |
|--------|--------|---|
| Token Exchange Success Rate | Entra audit logs | < 99% |
| Blob Storage Authentication Failures | Storage Analytics | > 0 in 5 min |
| Pod OIDC Token Rotation Delays | Kubernetes audit | > 70 min without rotation |
| Federated Credential Validation Errors | Entra audit | > 0 |
| RBAC Permission Denied Errors | Blob Storage logs | > 5 in 1 hour |

**Azure Monitor Query (KQL):**

```kusto
// Track workload identity token exchanges
AuditLogs
| where OperationName == "Exchange token using federated credentials"
| summarize 
    SuccessCount = countif(Result == "Success"),
    FailureCount = countif(Result == "Failure")
    by tostring(TargetResources[0].displayName), bin(TimeGenerated, 5m)
| extend SuccessRate = (SuccessCount * 100.0 / (SuccessCount + FailureCount))
| where SuccessRate < 99
```

---

## Compliance & Audit

### Security Certifications

This architecture supports:

- ✅ **SOC 2 Type II:** Cryptographic controls, access logging
- ✅ **ISO 27001:** Zero static credentials, RBAC enforcement
- ✅ **PCI DSS 3.4:** No hardcoded passwords/keys
- ✅ **HIPAA:** Audit trails for protected data access
- ✅ **FedRAMP:** OIDC federation with government cloud support

### Audit Trail

**Every authentication event creates audit records:**

```
Azure Entra Audit Log:
- Timestamp
- Principal (UAMI object ID)
- Operation (Token Exchange)
- Result (Success/Failure)
- IP Address
- User Agent

Azure Storage Analytics:
- Timestamp
- Principal (UAMI)
- Operation (e.g., GetBlob)
- Resource (blob name)
- Status (200/403/etc.)
- Duration

Kubernetes Audit Log:
- API server: Pod creation with service account
- Webhook: Token projection injected
```

**Compliance Evidence:**

```bash
# Export 90-day audit trail
az monitor activity-log list \
  --resource-group <rg> \
  --start-time 2026-05-20 \
  --query "[?contains(operationName.value, 'token')]" \
  --output json > audit_trail.json

# Validate no access denied in past 7 days
az storage logging off --account-name <storage> \
az storage logging show --account-name <storage> \
# Check for "AuthenticationFailed" events
```

---

## Summary

### Architecture Advantages

| Aspect | Benefit |
|--------|---------|
| **Security** | Zero secrets in pods, cryptographic proof, RBAC scoped access |
| **Operations** | Automatic token rotation, no key management overhead |
| **Auditability** | Full audit trail of every authentication event |
| **Compliance** | Meets SOC 2, ISO 27001, PCI DSS, HIPAA, FedRAMP |
| **Scalability** | No per-pod secrets to rotate; identity federation at cluster level |
| **Cost** | No additional licensing; UAMI included in Azure subscription |

### Key Design Principles Applied

1. **Zero Trust:** Every request validated cryptographically
2. **Defense in Depth:** Multiple validation layers (signature, claims, RBAC)
3. **Least Privilege:** Token scope + RBAC role limit permissions
4. **Auditability:** All operations logged for compliance
5. **Automation:** Token rotation and refresh automatic
6. **Immutability:** FIC once created cannot be modified (audit trail)

---

## Conclusion

Microsoft Entra Workload Identity provides a production-grade, cryptographically-sound authentication mechanism for Kubernetes workloads accessing Azure resources. By eliminating static credentials and leveraging OIDC federation, this architecture achieves the security posture required for enterprise and regulated workloads while reducing operational complexity.

**Suitable for:** Production AKS environments requiring zero-secret authentication to Azure data services.

---

**Document Version:** 1.0  
**Last Updated:** 2026-08-18  
**Classification:** Technical Architecture Review
