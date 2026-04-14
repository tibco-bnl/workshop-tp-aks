# NGINX to Traefik Ingress Controller Migration

**Migration Type:** Blue-Green Deployment Strategy  
**Date:** March 18, 2026  
**Cluster:** dp1-aks-aauk-kul (AKS, westeurope)  
**DNS Zone:** dp1.atsnl-emea.azure.dataplanes.pro  
**Reason:** Migrating from NGINX to Traefik for better cloud-native integration, Prometheus metrics, and v1.15.0 compatibility

---

## ✅ Completed Steps

### 1. Traefik Installation (01b-migrate-nginx-to-traefik.sh)

**Status:** ✅ Complete  
**Traefik Version:** Chart 39.0.5, App v3.6.10  
**LoadBalancer IP:** 20.54.225.126 (temporary)

**Configuration Highlights:**
- 2 replicas for HA with pod anti-affinity
- Prometheus metrics enabled with ServiceMonitor
- HTTP to HTTPS redirect via additionalArguments
- Azure LoadBalancer health probe configured (`/ping`)
- Resource limits: 500m-2000m CPU, 512Mi-2Gi memory
- TXT wildcard replacement for external-dns compatibility

**Schema Fixes Applied:**
Traefik Helm chart v39 introduced breaking changes from v33:
- ❌ Removed: `ports.web.redirectTo` → ✅ Moved to `additionalArguments`
- ❌ Removed: `ports.websecure.tls` → ✅ TLS enabled by default on websecure port
- ❌ Removed: `ingressClass.fallbackApiVersion` → ✅ No longer needed in v39
- ❌ Removed: `accessLog` (top-level) → ✅ Moved to `logs.access`
- ❌ Removed: `logs.access.filters.statusCodes` → ✅ Not supported in v39 schema

**Current Configuration:**
```yaml
additionalArguments:
  - "--serverstransport.insecureskipverify=true"
  - "--providers.kubernetesingress.ingressendpoint.ip=${INGRESS_LOAD_BALANCER_IP}"
  - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
  - "--entrypoints.web.http.redirections.entrypoint.scheme=https"

logs:
  general:
    level: INFO
  access:
    enabled: true
    format: json
```

---

### 2. External-DNS Configuration Fix (01d-fix-external-dns.sh)

**Status:** ✅ Complete  
**Issues Found:**
1. ❌ Wrong DNS zone: `dp1.kul.atsnl-emea.azure.dataplanes.pro` (included `.kul`)
2. ❌ Ingress class filter: `--ingress-class=nginx` (only watched nginx ingresses)

**Fixes Applied:**
```bash
# Before:
--domain-filter=dp1.kul.atsnl-emea.azure.dataplanes.pro
--ingress-class=nginx

# After:
--domain-filter=dp1.atsnl-emea.azure.dataplanes.pro
--annotation-filter=external-dns.alpha.kubernetes.io/hostname
# (removed ingress-class filter to watch both nginx and traefik)
```

**Result:**
- ✅ external-dns immediately detected Traefik service
- ✅ Created wildcard A record: `*.dp1.atsnl-emea.azure.dataplanes.pro` → `20.54.225.126`
- ✅ DNS propagated within 30 seconds
- ✅ Now watches both NGINX and Traefik ingresses with annotation filter

**Verification:**
```bash
$ nslookup test.dp1.atsnl-emea.azure.dataplanes.pro 8.8.8.8
Name:   test.dp1.atsnl-emea.azure.dataplanes.pro
Address: 20.54.225.126
```

---

### 3. Migration Scripts Created

#### 01e-enable-traefik-dashboard.sh
**Purpose:** Enable Traefik Web UI for monitoring and troubleshooting  
**Status:** ⏳ Not yet executed  
**Features:**
- Enables dashboard via Helm values update
- Provides port-forward instructions for local access
- Includes sample ingress configuration for external HTTPS access

**Usage:**
```bash
./01e-enable-traefik-dashboard.sh

# Then access locally:
kubectl port-forward -n ingress-system svc/traefik 9000:9000
# Open: http://localhost:9000/dashboard/
```

#### 01f-migrate-namespace.sh
**Purpose:** Migrate ingresses from nginx to traefik one namespace at a time  
**Status:** ⏳ Ready to use  
**Features:**
- Lists all nginx ingresses in target namespace
- Creates backup before migration
- Patches ingress resources to use traefik class
- Tests each host for accessibility
- Provides migration status summary

**Usage:**
```bash
# Recommended migration order:
./01f-migrate-namespace.sh elastic-system     # 3 ingresses (kibana, elastic, apm)
./01f-migrate-namespace.sh prometheus-system  # 1 ingress (grafana)
./01f-migrate-namespace.sh ai                 # 8 ingresses
./01f-migrate-namespace.sh bpm                # 1 ingress (production)
```

---

## Current Infrastructure State

### LoadBalancer Services

| Service | IP | Status |
|---------|-----|--------|
| **NGINX** | 128.251.247.140 | ✅ Active (original reserved IP) |
| **Traefik** | 20.54.225.126 | ✅ Active (temporary new IP) |

### DNS Records

| Record | Value | Status |
|--------|-------|--------|
| `*.dp1.atsnl-emea.azure.dataplanes.pro` | 20.54.225.126 | ✅ Points to Traefik |

### Ingress Resources to Migrate

| Namespace | NGINX Ingresses | Status |
|-----------|----------------|--------|
| `ai` | 8 | ⏳ Pending migration |
| `bpm` | 1 | ⏳ Pending migration |
| `elastic-system` | 3 | ⏳ Pending migration |
| `prometheus-system` | 1 | ⏳ Pending migration |
| **Total** | **13** | **0% migrated** |

#### Detailed Ingress List:
```
elastic-system:
  - dp-config-es-apm
  - dp-config-es-elastic
  - dp-config-es-kibana

prometheus-system:
  - kube-prometheus-stack-grafana

ai:
  - as-grid-as-vdb-grpc-documentstore
  - as-grid-as-vdb-grpc-ftlserver
  - as-grid-as-vdb-grpc-vectorstore
  - docling-serve
  - ollama-ai-workshop-ollama
  - open-webui
  - postgresql-pgadmin
  - postgresql-postgresql

bpm:
  - bpm-enterprise-ingress
```

### Ingress Controllers

| Name | Controller | Default | Age | Status |
|------|-----------|---------|-----|--------|
| `nginx` | k8s.io/ingress-nginx | ❌ | 187d | ⏳ Being replaced by Traefik |
| `traefik` | traefik.io/ingress-controller | ✅ | ~8m | ✅ New default controller |
| `azure-application-gateway` | azure/application-gateway | ❌ | 188d | ℹ️ Azure resource (unused) |
| `tibco-dp-d31hm0jnpmmc73b2qfeg` | haproxy.org/ingress-controller | ❌ | 187d | ⚠️ **Can be removed** (old TIBCO DP: `d31hm0jnpmmc73b2qfeg`) |

**Note:** The `tibco-dp-d31hm0jnpmmc73b2qfeg` ingress class was created by a previous TIBCO Data Plane installation (DP ID: `d31hm0jnpmmc73b2qfeg`). It is no longer needed and can be safely removed after the new v1.15.0 Data Plane is installed.

---

## 📋 Migration Plan (Blue-Green Strategy)

### Phase 1: Setup ✅ COMPLETE
- [x] Install Traefik alongside NGINX
- [x] Fix external-dns configuration
- [x] Verify DNS auto-updates working
- [x] Create migration helper scripts

### Phase 2: Gradual Migration ⏳ READY TO START
```bash
# Step 1: Enable Traefik Dashboard (optional but recommended)
./01e-enable-traefik-dashboard.sh

# Step 2: Migrate monitoring namespaces first (easy to verify)
./01f-migrate-namespace.sh elastic-system
# Verify: curl -k -I https://kibana.dp1.atsnl-emea.azure.dataplanes.pro

./01f-migrate-namespace.sh prometheus-system  
# Verify: curl -k -I https://grafana.dp1.atsnl-emea.azure.dataplanes.pro

# Step 3: Migrate application namespaces
./01f-migrate-namespace.sh ai
# Verify each app is accessible

./01f-migrate-namespace.sh bpm
# Verify production BPM app is accessible

# Step 4: Verify all applications working via Traefik
```

### Phase 3: Finalization 🔜 AFTER VERIFICATION
```bash
# Remove NGINX to release 128.251.247.140
./01c-finalize-traefik-migration.sh

# This will:
# 1. Verify no ingresses use nginx class
# 2. Backup NGINX configuration
# 3. Uninstall NGINX Helm releases
# 4. Wait for Azure to release 128.251.247.140
# 5

### Phase 4: Cleanup (Optional) 🧹 AFTER v1.15.0 INSTALLATION
```bash
# Remove old TIBCO Data Plane ingress class (from DP ID: d31hm0jnpmmc73b2qfeg)
kubectl delete ingressclass tibco-dp-d31hm0jnpmmc73b2qfeg
Migrate from NGINX to Traefik?

### Benefits of Traefik for TIBCO Platform v1.15.0:
✅ **Cloud-Native Design** - Built for Kubernetes with native CRD support  
✅ **Better Observability** - Native Prometheus metrics integration  
✅ **Modern Features** - HTTP/3, built-in middleware, better routing  
✅ **TIBCO Recommendation** - Recommended ingress controller for v1.15.0  
✅ **Lighter Resource Usage** - More efficient than NGINX for Kubernetes workloads  

### Why Blue-Green Migration?
✅ **Zero Downtime** - Both NGINX and Traefik run simultaneously during migration  
✅ **Gradual Rollout** - Migrate namespace by namespace, verify each step  
✅ **Easy Rollback** - Revert individual namespaces if issues occur  
✅ **DNS Automation** - external-dns handles record updates automatically (no manual DNS changes!)  
✅ **Independent Testing** - Verify each namespace before proceeding  
✅ **Production Safe** - No service interruption for running applications  

### Why Not Swap IPs Immediately?
Azure LoadBalancer IPs are **exclusive** - only one service can use an IP at a time:
- NGINX currently holds `128.251.247.140` (original reserved IP)
- Traefik gets new IP `20.54.225.126` (temporary during migration)
- After NGINX removal, Azure releases `128.251.247.140`
- Traefik reclaims the original IP via Helm upgrade 
✅ **Gradual Rollout** - Migrate namespace by namespace  
✅ **Easy Rollback** - Revert individual namespaces if issues occur  
✅ **DNS Automation** - external-dns handles record updates automatically  
✅ **Independent Testing** - Verify each namespace before proceeding  

### Why Not Swap IPs Immediately?
Azure LoadBalancer IPs are **exclusive** - only one service can use an IP at a time:
- NGINX currently holds `128.251.247.140`
- Traefik got new IP `20.54.225.126` 
- After NGINX removal, Traefik can reclaim the original IP
- DNS automatically updates via external-dns (no manual changes needed!)

---

## Infrastructure Components

### Cluster Details
- **Name:** dp1-aks-aauk-kul
- **Region:** westeurope
- **Resource Group:** kul-atsbnl
- **Subscription:** azrpsemeaneth-PresalesEMEANetherlands
- **Kubernetes Version:** v1.32.6
- **Nodes:** 2x Standard_D4s_v3

### Supporting Services (Already Installed)
- ✅ **cert-manager** v1.x (namespace: cert-manager)
- ✅ **external-dns** v0.15.1 (namespace: external-dns-system)
- ✅ **Prometheus Stack** 48.3.4 (needs upgrade to 69.3.3 for v1.15.0)
- ✅ **Elasticsearch** 8.17.3 via ECK Operator 2.16.0 (correct version)
- ✅ **Kibana** 8.17.3

---

## Troubleshooting & Rollback

### If Migration Issues Occur

**Rollback Single Namespace:**
```bash
# Restore ingresses to nginx
kubectl patch ingress <ingress-name> -n <namespace> \
  --type=merge -p '{"spec":{"ingressClassName":"nginx"}}'
```

**Rollback external-dns Configuration:**
```bash
# Restore from backup
kubectl apply -f ./backups/YYYYMMDD-HHMMSS-external-dns-backup.yaml
```

**Rollback Traefik Installation:**
```bash
# Remove Traefik
helm uninstall traefik -n ingress-system

# DNS will automatically revert to NGINX's IP
```

### Common Issues

**Issue: Service not accessible after migration**
```bash
# Check ingress configuration
kubectl describe ingress <name> -n <namespace>

# Check Traefik logs
kubectl logs -n ingress-system -l app.kubernetes.io/name=traefik --tail=100

# Verify service/pods are running
kubectl get pods,svc -n <namespace>

# Test DNS resolution
nslookup <hostname>.dp1.atsnl-emea.azure.dataplanes.pro
```

**Issue: DNS not updating**
```bash
# Check external-dns logs
kubectl logs -n external-dns-system deploy/external-dns --tail=50

# Verify annotation on service
kubectl get svc <name> -n <namespace> -o yaml | grep external-dns

# Force external-dns sync
kubectl rollout restart deployment external-dns -n external-dns-system
```

**Issue: Certificate errors**
```bash
# Check cert-manager
kubectl get certificate,certificaterequest -A

# Check ingress TLS configuration
kubectl get ingress <name> -n <namespace> -o yaml | grep -A5 tls
```

---

## Next Steps After Migration

1. **Update Environment Variables**
   ```bash
   # Edit 00-environment-v1.15.sh
   export INGRESS_CONTROLLER="traefik"
   export INGRESS_LOAD_BALANCER_IP="128.251.247.140"
   ```

2. **Upgrade Prometheus Stack**
   ```bash
   ./02-upgrade-prometheus.sh  # 48.3.4 → 69.3.3
   ```

3. **Verify Observability Stack**
   ```bash
   ./03-verify-observability.sh
   ```

4. **Install TIBCO Platform Control Plane v1.15.0**
   ```bash
   ./04-install-controlplane.sh
   # Access: https://admin.dp1.atsnl-emea.azure.dataplanes.pro
   ```

5. **Install TIBCO Platform Data Plane v1.15.0**
   ```bash
7. **Cleanup Old Resources (Optional)**
   ```bash
   # Remove old TIBCO Data Plane ingress class
   kubectl delete ingressclass tibco-dp-d31hm0jnpmmc73b2qfeg
   
   # The old DP ID was: d31hm0jnpmmc73b2qfeg
   # New v1.15.0 DP will use: dp1 (cleaner naming convention)
   ```

   ./05-install-dataplane.sh
   # Access: https://tunnel.dp1.atsnl-emea.azure.dataplanes.pro
   ```

6. **Post-Install Verification**
   ```bash
   ./06-post-install-verification.sh
   ```

---

## Files Created/Modified

### New Scripts:
- `01d-fix-external-dns.sh` - Fix external-dns configuration (✅ executed)
- `01e-enable-traefik-dashboard.sh` - Enable Traefik Web UI
- `01f-migrate-namespace.sh` - Gradual namespace migration tool
- `MIGRATION-SUMMARY.md` - This document

### Modified Scripts:
- `01b-migrate-nginx-to-traefik.sh` - Fixed Traefik v39 schema compatibility
- `01c-finalize-traefik-migration.sh` - Will be updated to handle IP reclaim

### Backups Created:
- `./backups/YYYYMMDD-HHMMSS/` - Automatic backups before each operation
  - external-dns deployment YAML
  - Ingress resources before migration
  - NGINX Helm values (at finalization)

---

## Key Learnings

### Traefik Helm Chart v39 Breaking Changes
The migration from chart v33 to v39 required significant configuration changes:
- Port redirections moved to additionalArguments
### Old TIBCO Data Plane Cleanup
The ingress class `tibco-dp-d31hm0jnpmmc73b2qfeg` is a leftover from a previous TIBCO Data Plane installation:
- **Old DP ID:** `d31hm0jnpmmc73b2qfeg` (auto-generated hash-based ID)
- **New DP ID:** `dp1` (clean, human-readable ID following v1.15.0 naming conventions)
- **Controller:** HAProxy-based (older TIBCO ingress implementation)
- **Status:** No longer needed, can be removed after v1.15.0 DP installation
- **Removal:** `kubectl delete ingressclass tibco-dp-d31hm0jnpmmc73b2qfeg`

The new TIBCO Platform v1.15.0 will use Traefik as the ingress controller instead of creating its own HAProxy-based controller.

- TLS configuration simplified (enabled by default on websecure)
- Access log filtering options removed
- Ingress class fallback API version deprecated

Reference: https://github.com/traefik/traefik-helm-chart/tree/v39.0.5

### External-DNS Best Practices
- Use `--annotation-filter` instead of `--ingress-class` for multi-controller support
- Verify DNS zone names match Azure DNS exactly (no extra subdomains)
- Monitor external-dns logs during updates to confirm record creation
- TXT records track ownership for cleanup (`wildcard`, `a-wildcard`)

### Azure LoadBalancer IP Behavior
- IPs are exclusive to one service at a time
- Releasing an IP requires service deletion (spec.loadBalancerIP patching doesn't force release)
- DNS propagation is fast (~30 seconds) when external-dns is configured properly
- Reserved IPs should be documented in resource group tags

---

## References

- **TIBCO Platform v1.15.0 Documentation:** https://docs.tibco.com/pub/platform-cp/latest/
- **Traefik Helm Chart:** https://github.com/traefik/traefik-helm-chart
- **External-DNS Documentation:** https://github.com/kubernetes-sigs/external-dns
- **Cert-Manager Documentation:** https://cert-manager.io/docs/

---

**Migration Status:** 🟡 In Progress (Phase 2)  
**Last Updated:** 2026-03-18 14:30 UTC  
**Contact:** kul@atsbnl  
