# Helm Chart Assessment Report: shows-api

**Date:** 2026-08-18  
**Chart:** helm/shows-api  
**Version:** 1.0.0  

---

## Executive Summary

The Helm chart for the FastAPI shows-api is **production-ready** and meets all assessment requirements. The chart is fully parameterized, supports Azure Workload Identity, includes proper health checks, and enforces security best practices.

---

## Assessment Results

### ✅ 1. Helm Lint Validation

```
==> Linting helm/shows-api
1 chart(s) linted, 0 chart(s) failed
```

**Status:** ✅ PASSED - No errors or warnings

---

### ✅ 2. All Values Parameterized

**Complete parameterization verified:**

| Category | Parameters | Status |
|----------|-----------|--------|
| **Replica Count** | `replicaCount` | ✅ Configurable (default: 2) |
| **Image Configuration** | `image.repository`, `image.tag`, `image.pullPolicy` | ✅ All configurable |
| **Namespace** | `namespace` | ✅ Configurable (defaults to release namespace) |
| **ServiceAccount** | `serviceAccount.create`, `.name`, `.automountServiceAccountToken` | ✅ All configurable |
| **Workload Identity** | `workloadIdentity.enabled`, `.clientId` | ✅ All configurable |
| **Service** | `service.type`, `.port`, `.targetPort`, `.annotations` | ✅ All configurable |
| **Container Port** | `containerPort` | ✅ Configurable (default: 8080) |
| **Readiness Probe** | `probes.readiness.*` (path, delays, thresholds) | ✅ All configurable |
| **Liveness Probe** | `probes.liveness.*` (path, delays, thresholds) | ✅ All configurable |
| **Resource Requests** | `resources.requests.cpu`, `.memory` | ✅ Both configurable |
| **Resource Limits** | `resources.limits.cpu`, `.memory` | ✅ Both configurable |
| **Pod Configuration** | `podAnnotations`, `nodeSelector`, `affinity`, `tolerations` | ✅ All configurable |
| **Environment Config** | `config` (ConfigMap key-value pairs) | ✅ Fully dynamic via ConfigMap |

**Total Configurable Parameters:** 30+

---

### ✅ 3. Image Repository and Tag Configurable

**Verification:** Custom values render correctly

```bash
helm template prod-release helm/shows-api \
  --set image.repository=myacr.azurecr.io/shows-api \
  --set image.tag=2.5.3
```

**Result:**
```yaml
image: "myacr.azurecr.io/shows-api:2.5.3"
```

✅ Both repository and tag are properly parameterized

---

### ✅ 4. Namespace Configurable

**Verification:** Custom namespace renders correctly

```bash
helm template prod-release helm/shows-api \
  --set namespace=production
```

**Result:**
```yaml
namespace: production
```

Applied to:
- ✅ ServiceAccount metadata
- ✅ Deployment metadata
- ✅ Service metadata
- ✅ ConfigMap metadata

---

### ✅ 5. ServiceAccount Supports Azure Workload Identity

**Template Location:** `templates/serviceaccount.yaml`

**Workload Identity Annotation:**
```yaml
metadata:
  annotations:
    azure.workload.identity/client-id: "{{ .Values.workloadIdentity.clientId }}"
```

**Configuration:**
```yaml
workloadIdentity:
  enabled: true
  clientId: ""  # Set via --set or values override
```

**Verification:** Custom Workload Identity renders correctly

```bash
helm template prod-release helm/shows-api \
  --set workloadIdentity.clientId="12345678-1234-1234-1234-123456789012"
```

**Result:**
```yaml
metadata:
  annotations:
    azure.workload.identity/client-id: "12345678-1234-1234-1234-123456789012"
```

**Pod Label (in Deployment):**
```yaml
metadata:
  labels:
    azure.workload.identity/use: "true"
```

✅ Both ServiceAccount annotation and Pod label correctly configured

---

### ✅ 6. No Hardcoded Environment Values

**Findings:**

#### Chart.yaml
✅ No environment-specific values
- Uses template variables, no hardcoded hosts/URLs
- Version and metadata are configurable

#### values.yaml
✅ No hardcoded secrets or sensitive data
- `image.repository` uses placeholder: `ghcr.io/example/shows-api`
- `workloadIdentity.clientId` is empty (must be provided)
- `namespace` is empty (defaults to release namespace)
- `config.LOG_LEVEL` has sensible default: `"info"`

#### Deployment template
✅ All values use template variables
```yaml
namespace: {{ default .Release.Namespace .Values.namespace }}
image: "{{ .Values.image.repository }}:{{ .Values.image.tag }}"
replicas: {{ .Values.replicaCount }}
containerPort: {{ .Values.containerPort }}
```

#### ConfigMap template
✅ Fully dynamic configuration
```yaml
data:
  {{- range $key, $value := .Values.config }}
  {{ $key }}: {{ $value | quote }}
  {{- end }}
```

**Example:** Custom config values render correctly
```bash
helm template shows-api helm/shows-api \
  --set config.BLOB_STORAGE_ENABLED=true \
  --set config.STORAGE_ACCOUNT_URL=https://mystg.blob.core.windows.net
```

**Result:**
```yaml
data:
  BLOB_STORAGE_ENABLED: "true"
  LOG_LEVEL: "info"
  STORAGE_ACCOUNT_URL: "https://mystg.blob.core.windows.net"
```

✅ No hardcoded values found

---

## Component Verification

### ✅ Deployment

**Location:** `templates/deployment.yaml`

| Requirement | Status | Details |
|---|---|---|
| Replicas configurable | ✅ | `{{ .Values.replicaCount }}` |
| Image configurable | ✅ | Repository + tag from values |
| Container port configurable | ✅ | `{{ .Values.containerPort }}` |
| Rolling update strategy | ✅ | maxSurge: 1, maxUnavailable: 0 |
| Security context | ✅ | Non-root, read-only FS, no capabilities |
| Service account reference | ✅ | Proper naming convention |

---

### ✅ Service

**Location:** `templates/service.yaml`

| Requirement | Status | Details |
|---|---|---|
| Type configurable | ✅ | Default: ClusterIP |
| Port configurable | ✅ | `{{ .Values.service.port }}` |
| Target port configurable | ✅ | References named port "http" |
| Annotations support | ✅ | `{{ .Values.service.annotations }}` |
| Labels correct | ✅ | Kubernetes standard labels |

---

### ✅ ServiceAccount

**Location:** `templates/serviceaccount.yaml`

| Requirement | Status | Details |
|---|---|---|
| Create flag | ✅ | `{{ if .Values.serviceAccount.create }}` |
| Name configurable | ✅ | Defaults to `{release}-sa` |
| Workload Identity annotation | ✅ | Conditionally added if enabled |
| Token mounting configurable | ✅ | `automountServiceAccountToken` |
| Version label | ✅ | `app.kubernetes.io/version` |

---

### ✅ Readiness Probe

**Configuration:**
```yaml
readinessProbe:
  httpGet:
    path: /health              # Correct endpoint
    port: http                 # Named port reference
    scheme: HTTP
  initialDelaySeconds: 10      # Allows startup
  periodSeconds: 10            # Check every 10s
  timeoutSeconds: 3
  failureThreshold: 3
  successThreshold: 1
```

**Verification:**
- ✅ Path: `/health` - Correct FastAPI endpoint
- ✅ Port: Named reference to `http` port (8080)
- ✅ Initial delay: 10 seconds (appropriate for FastAPI startup)
- ✅ Period: 10 seconds (reasonable check interval)
- ✅ Timeout: 3 seconds (appropriate for local health check)
- ✅ Failure threshold: 3 (prevents false failures)

**All fields parameterized:**
```yaml
probes:
  readiness:
    path: {{ .Values.probes.readiness.path }}
    initialDelaySeconds: {{ .Values.probes.readiness.initialDelaySeconds }}
    periodSeconds: {{ .Values.probes.readiness.periodSeconds }}
    timeoutSeconds: {{ .Values.probes.readiness.timeoutSeconds }}
    failureThreshold: {{ .Values.probes.readiness.failureThreshold }}
```

---

### ✅ Liveness Probe

**Configuration:**
```yaml
livenessProbe:
  httpGet:
    path: /health              # Correct endpoint
    port: http                 # Named port reference
    scheme: HTTP
  initialDelaySeconds: 20      # Longer delay (avoid premature restarts)
  periodSeconds: 20            # Check every 20s (less frequent)
  timeoutSeconds: 3
  failureThreshold: 3
  successThreshold: 1
```

**Verification:**
- ✅ Path: `/health` - Correct FastAPI endpoint
- ✅ Port: Named reference to `http` port (8080)
- ✅ Initial delay: 20 seconds (gives app time to stabilize)
- ✅ Period: 20 seconds (less frequent than readiness)
- ✅ Timeout: 3 seconds (appropriate)
- ✅ Failure threshold: 3 (prevents restart loops)

**All fields parameterized:** Same structure as readiness probe

---

### ✅ Resource Requests

**Configuration:**
```yaml
resources:
  requests:
    cpu: 100m              # 0.1 CPU cores reserved
    memory: 128Mi          # 128 MiB reserved
```

**Parameterized:** ✅ Yes
```yaml
resources:
  {{- toYaml .Values.resources | nindent 12 }}
```

**Purpose:**
- Kubernetes reserves these resources on node
- Prevents oversubscription
- Allows proper scheduler decisions
- Ensures pod QoS class

---

### ✅ Resource Limits

**Configuration:**
```yaml
resources:
  limits:
    cpu: 500m              # Max 0.5 CPU cores
    memory: 512Mi          # Max 512 MiB
```

**Parameterized:** ✅ Yes

**Purpose:**
- Pod is throttled if exceeding CPU limit
- Pod is killed if exceeding memory limit
- Prevents runaway containers
- Protects cluster stability

**Resource Ratio:** Requests = 20% of Limits
- Conservative for efficient packing
- Room for spikes
- Appropriate for FastAPI workload

---

## Template Rendering Verification

### Default Values
```bash
helm template shows-api helm/shows-api
```
✅ Renders correctly with defaults

### Custom Values (Comprehensive Test)
```bash
helm template prod-release helm/shows-api \
  --set image.repository=myacr.azurecr.io/shows-api \
  --set image.tag=2.5.3 \
  --set namespace=production \
  --set replicaCount=5 \
  --set workloadIdentity.clientId="12345678-1234-1234-1234-123456789012" \
  --set config.BLOB_STORAGE_ENABLED=true \
  --set config.STORAGE_ACCOUNT_URL=https://mystg.blob.core.windows.net
```

**Verification Results:**
- ✅ Namespace: `production`
- ✅ Image: `myacr.azurecr.io/shows-api:2.5.3`
- ✅ Replicas: `5`
- ✅ Workload Identity Client ID: `12345678-1234-1234-1234-123456789012`
- ✅ ConfigMap includes all custom values
- ✅ No hardcoded values override

---

## Security Analysis

### ✅ Pod Security Context
```yaml
securityContext:
  runAsNonRoot: true             # Non-root required
  runAsUser: 10001               # Unprivileged UID
  fsGroup: 10001                 # File system group
```

### ✅ Container Security Context
```yaml
securityContext:
  allowPrivilegeEscalation: false # Prevent escalation
  capabilities:
    drop:
      - ALL                       # Drop all capabilities
  readOnlyRootFilesystem: true    # Immutable root FS
```

### ✅ Volume Security
```yaml
volumeMounts:
  - name: tmp
    mountPath: /tmp              # Writable tmpfs for app
volumes:
  - name: tmp
    emptyDir: {}                 # Per-pod temporary storage
```

### ✅ RBAC Support
```yaml
serviceAccount:
  create: true
  automountServiceAccountToken: true
```

### ✅ Workload Identity
```yaml
azure.workload.identity/client-id: ...   # ServiceAccount annotation
azure.workload.identity/use: "true"      # Pod label
```

---

## Kubernetes Best Practices

✅ **Standard Labels Applied:**
- `app.kubernetes.io/name` - Chart name
- `app.kubernetes.io/instance` - Release name
- `app.kubernetes.io/version` - App version
- `app.kubernetes.io/managed-by` - Helm

✅ **Resource Definitions:**
- Requests and limits defined
- Appropriate ratio (1:5)
- Suitable for FastAPI workload

✅ **Health Checks:**
- Readiness probe configured
- Liveness probe configured
- Proper endpoint (/health)
- Reasonable timings

✅ **Deployment Strategy:**
- RollingUpdate strategy
- maxSurge: 1 (one extra pod during update)
- maxUnavailable: 0 (no downtime)

✅ **Service Configuration:**
- ClusterIP type (no external exposure in chart)
- Named ports
- Proper selectors

---

## Configuration Examples

### Basic Deployment
```bash
helm install shows-api helm/shows-api
```

### Production Deployment
```bash
helm install shows-api helm/shows-api \
  --namespace production \
  --create-namespace \
  --set image.repository=myacr.azurecr.io/shows-api \
  --set image.tag=2.0.0 \
  --set replicaCount=3 \
  --set workloadIdentity.clientId="12345678-1234-1234-1234-123456789012" \
  --set resources.requests.cpu=250m \
  --set resources.requests.memory=256Mi \
  --set resources.limits.cpu=1000m \
  --set resources.limits.memory=1Gi
```

### With Blob Storage Caching
```bash
helm install shows-api helm/shows-api \
  --namespace production \
  --set image.tag=2.0.0 \
  --set workloadIdentity.clientId="<client-id>" \
  --set config.BLOB_STORAGE_ENABLED=true \
  --set config.STORAGE_ACCOUNT_URL=https://mystg.blob.core.windows.net \
  --set config.CACHE_CONTAINER_NAME=shows-cache \
  --set config.CACHE_TTL_HOURS=24
```

---

## Summary Table

| Requirement | Status | Evidence |
|---|---|---|
| **Helm lint passes** | ✅ PASS | 0 failures, 0 warnings |
| **All values parameterized** | ✅ PASS | 30+ configurable parameters |
| **Image repo configurable** | ✅ PASS | `image.repository` via values |
| **Image tag configurable** | ✅ PASS | `image.tag` via values |
| **Namespace configurable** | ✅ PASS | Applied to all resources |
| **ServiceAccount WI support** | ✅ PASS | Annotation + Pod label |
| **No hardcoded env values** | ✅ PASS | ConfigMap fully dynamic |
| **Deployment template** | ✅ PASS | All fields parameterized |
| **Service template** | ✅ PASS | Type, port, annotations configurable |
| **ServiceAccount template** | ✅ PASS | Create, name, WI support |
| **Readiness probe** | ✅ PASS | /health, 10s period, 10s initial delay |
| **Liveness probe** | ✅ PASS | /health, 20s period, 20s initial delay |
| **Resource requests** | ✅ PASS | CPU: 100m, Memory: 128Mi |
| **Resource limits** | ✅ PASS | CPU: 500m, Memory: 512Mi |

---

## Recommendations

### Current Status: ✅ NO IMPROVEMENTS NEEDED

The chart fully meets all assessment requirements and follows Kubernetes/Helm best practices. The following aspects are already implemented:

1. ✅ Complete parameterization
2. ✅ Workload Identity support
3. ✅ Proper health checks
4. ✅ Security hardening
5. ✅ Resource management
6. ✅ No hardcoded values

### Optional Future Enhancements (Out of Scope)

- Add optional ingress template
- Add horizontal pod autoscaler (HPA) template
- Add network policy templates
- Add PodDisruptionBudget template

---

## Conclusion

**ASSESSMENT RESULT: ✅ PASS**

The shows-api Helm chart is **production-ready** and meets all specified requirements:
- ✅ Fully parameterized
- ✅ Secure by default
- ✅ Azure Workload Identity compatible
- ✅ Proper health checks
- ✅ Resource-constrained
- ✅ Follows Kubernetes best practices

**Recommendation:** Ready for deployment to AKS production environments.

---

**Report Generated:** 2026-08-18  
**Chart Location:** `helm/shows-api/`  
**Chart Version:** 1.0.0  
**Status:** ✅ PRODUCTION READY
