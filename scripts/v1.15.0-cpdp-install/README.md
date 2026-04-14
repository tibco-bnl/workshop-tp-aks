# TIBCO Platform v1.15.0 Installation Scripts

This directory contains scripts for installing TIBCO Platform v1.15.0 with DNS simplification on the `dp1-aks-aauk-kul` AKS cluster.

## Overview

These scripts implement the v1.15.0 DNS simplification architecture where services use single-level subdomains (e.g., `admin.example.com`) instead of multi-level subdomains (e.g., `admin.cp1-my.apps.example.com`).

## Prerequisites

- Azure CLI logged in
- kubectl configured for dp1-aks-aauk-kul cluster
- Helm 3.13+
- Access to TIBCO container registry
- DNS zone: `dp1.atsnl-emea.azure.dataplanes.pro`

## Existing Infrastructure

The cluster already has:
- ✅ NGINX Ingress (dp-config-aks-nginx) in `ingress-system` (will migrate to Traefik)
- ⚠️ Prometheus Stack v48.3.4 in `prometheus-system` (will be upgraded to 69.3.3)
- ✅ Elasticsearch 8.17.3 with ECK operator 2.16.0 in `elastic-system`
- ⚠️ Old TIBCO Data Plane (DP ID: `d31hm0jnpmmc73b2qfeg`) - will be cleaned up
- LoadBalancer IP: `128.251.247.140`

## Installation Steps

**Note:** The cluster is currently being migrated from NGINX to Traefik. See [MIGRATION-SUMMARY.md](MIGRATION-SUMMARY.md) for detailed migration status and instructions.

### Path A: Migrate to Traefik (Recommended for v1.15.0) 🔄 IN PROGRESS

Traefik is recommended for v1.15.0 as it provides better cloud-native integration, Prometheus metrics, and modern ingress features.

**Current Status:**
- ✅ Traefik installed (IP: 20.54.225.126)
- ✅ external-dns fixed and auto-updating DNS
- ⏳ 13 ingress resources pending migration from NGINX

**Migration Steps:**

```bash
# 1. Enable Traefik Dashboard (optional but helpful)
./01e-enable-traefik-dashboard.sh

# 2. Migrate namespaces incrementally (recommended order)
./01f-migrate-namespace.sh elastic-system      # 3 ingresses
./01f-migrate-namespace.sh prometheus-system   # 1 ingress  
./01f-migrate-namespace.sh ai                  # 8 ingresses
./01f-migrate-namespace.sh bpm                 # 1 ingress

# 3. After verifying all apps work, finalize migration
./01c-finalize-traefik-migration.sh
# This removes NGINX and reclaims IP 128.251.247.140 for Traefik

# 4. Continue with Prometheus upgrade
./02-upgrade-prometheus.sh
```

**Benefits:**
- Zero downtime migration
- Namespace-by-namespace rollout with easy rollback
- Automatic DNS updates via external-dns
- Better observability with Prometheus metrics

See [MIGRATION-SUMMARY.md](MIGRATION-SUMMARY.md) for complete details, troubleshooting, and rollback procedures.

### Path B: Continue with NGINX (Alternative)

If you prefer to keep NGINX, you can update it and continue:

```bash
# Update NGINX configuration (fix DNS, add IP whitelisting)
./01-update-ingress.sh
```

---

### Step 1: Configure Environment

Edit `00-environment-v1.15.sh` and update:
- Container registry credentials
- IP whitelisting ranges (for production security)
- Certificate email address

```bash
vi 00-environment-v1.15.sh

# Update these values:
export CONTAINER_REGISTRY_SERVER="your-registry.azurecr.io"
export CONTAINER_REGISTRY_USERNAME="your-username"
export CONTAINER_REGISTRY_PASSWORD="your-password"
export TP_AUTHORIZED_IP_RANGE="1.2.3.4/32,10.0.0.0/8"
```

Then source the environment:

```bash
source 00-environment-v1.15.sh
show_config
validate_prerequisites
```

### Step 2: Ingress Controller Setup

**Choose your path:**
- **Path A (Recommended):** Migrate to Traefik - See "Path A" section above
- **Path B:** Update NGINX - See "Path B" section above

### Step 3: Upgrade Prometheus Stack

Upgrade Prometheus from v48.3.4 to v69.3.3 (required for v1.15.0):

```bash
# Upgrade Prometheus 48.3.4 → 69.3.3
./02-upgrade-prometheus.sh
```

This script:
- Backs up current configuration
- Upgrades to kube-prometheus-stack 69.3.3
- Configures Grafana with ingress
- Integrates with Elasticsearch for logs

### Step 4: Verify Observability Stack

Check Elasticsearch and Prometheus are healthy:

```bash
# Verify observability stack
./03-verify-observability.sh
```

### Step 5: Install Control Plane

Install TIBCO Platform Control Plane v1.15.0:

```bash
# Install Control Plane v1.15.0
./04-install-controlplane.sh
# Access: https://admin.dp1.atsnl-emea.azure.dataplanes.pro
```

This script:
- Creates namespace and service accounts
- Generates/uses TLS certificates
- Installs Control Plane with simplified DNS
- Access URL: `https://admin.dp1.atsnl-emea.azure.dataplanes.pro`
Step 6:
### 6. Register Data Plane and Get Token

1. Access Control Plane UI: `https://admin.dp1.atsnl-emea.azure.dataplanes.pro`
2. Navigate to **Settings** → **Data Planes**
3. Click **Register Data Plane**
4. Fill in:
   - Data Plane ID: `dp1`
   - Description: "dp1-aks-aauk-kul Data Plane"
5. Click **Generate Token**
6. Copy the token and set it:

```bash
export TP_DP_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."
echo 'export TP_DP_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."' >> 00-environment-v1.15.sh
```
Step 7:
### 7. Install Data Plane

Install TIBCO Platform Data Plane v1.15.0:

```bash
# Install Data Plane v1.15.0
./05-install-dataplane.sh
```

This script:
- Creates namespace and secrets
- Installs Data Plane with simplified DNS
- Connects to Control Plane via tunnel
- Enables BWCE, Flogo, and EMS capabilities

### Step 8: Post-Installation Verification

Verify the complete installation:

```bash
# Post-install verification
./06-post-install-verification.sh
```

This checks:
- Control Plane and Data Plane pod status
- DNS resolution
- Connectivity tests
- Observability stack integration

### Step 9: Cleanup Old Resources (Optional)

Remove old TIBCO Data Plane resources from previous installation:

```bash
# Check migration status and identify old resources
./migration-status.sh

# Cleanup old TIBCO Data Plane ingress class (DP ID: d31hm0jnpmmc73b2qfeg)
./cleanup-old-dp.sh
```

**What gets cleaned up:**
- Old ingress class: `tibco-dp-d31hm0jnpmmc73b2qfeg` (HAProxy-based)
- Old Data Plane pods (if still running)
- Old Helm releases (if any)

**When to run:**
- After v1.15.0 Data Plane is installed and verified
- After all applications are migrated to new Data Plane
- Before final cluster cleanup

The new v1.15.0 installation uses:
- **Ingress Controller:** Traefik (shared, modern)
- **DP ID:** `dp1` (clean, human-readable)
- **Namespace:** `dp1-ns` (following naming conventions)

---

## v1.15.0 DNS Architecture

### Simplified Structure (v1.15.0+)

- **Control Plane**: `admin.dp1.atsnl-emea.azure.dataplanes.pro`
- **Tunnel**: `tunnel.dp1.atsnl-emea.azure.dataplanes.pro`
- **Applications**: `app-name.dp1.atsnl-emea.azure.dataplanes.pro`

### Key Benefits

- Simpler DNS management (single-level subdomains)
- Easier certificate management
- More intuitive URLs
- Consistent with cloud-native patterns

## Access URLs

After installation:

| Service | URL | Credentials |
|---------|-----|-------------|
| Control Plane UI | https://admin.dp1.atsnl-emea.azure.dataplanes.pro | Setup during installation |
| Kibana | https://kibana.dp1.atsnl-emea.azure.dataplanes.pro | user: elastic, get password from secret |
| Grafana | https://grafana.dp1.atsnl-emea.azure.dataplanes.pro | user: admin, get password from secret |

Get credentials:

```bash
# Elasticsearch password
kubectl get secret dp-config-es-es-elastic-user -n elastic-system \
  -o go-template='{{.data.elastic | base64decode}}'

# Grafana password
kubectl get secret kube-prometheus-stack-grafana -n prometheus-system \
  -o jsonpath='{.data.admin-password}' | base64 -d
```

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n tibco-platform-cp
kubectl get pods -n tibco-platform-dp
```

### View Logs

```bash
# Control Plane
kubectl logs -n tibco-platform-cp -l app.kubernetes.io/component=cp-core -f

# Data Plane
kubectl logs -n tibco-platform-dp -l app.kubernetes.io/component=dp-core-ops -f
```

### Test DNS Resolution

```bash
dig +short admin.dp1.atsnl-emea.azure.dataplanes.pro
# Should return: 128.251.247.140
```

### Test Connectivity

```bash
curl -k -I https://admin.dp1.atsnl-emea.azure.dataplanes.pro
```

### Check Data Plane Connection

In Control Plane UI:
1. Navigate to **Settings** → **Data Planes**
2. Verify `dp1` shows as **Connected** with green indicator

## Rollback

If needed, rollback using Helm:

```bash
# List releases
helm list -A

# Rollback Control Plane
helm rollback tibco-cp -n tibco-platform-cp

# Rollback Data Plane
helm rollback tibco-dp -n tibco-platform-dp

# Rollback Prometheus
helm rollback kube-prometheus-stack -n prometheus-system
```

## Security Notes

1. **IP Whitelisting**: Update `TP_AUTHORIZED_IP_RANGE` to restrict access
2. **Certificates**: Replace self-signed certificates with Let's Encrypt or corporate CA
3. **Secrets**: Rotate container registry credentials regularly
4. **Passwords**: Change default Grafana password immediately

## Support

For issues or questions:
- Check TIBCO Platform documentation: https://docs.tibco.com/pub/platform-cp/latest
- View workshop guides: https://github.com/tibco-bnl/workshop-tp-aks
- Contact TIBCO Support

---

**Version**: 1.15.0  
**Last Updated**: March 18, 2026  
**Cluster**: dp1-aks-aauk-kul  
**DNS**: dp1.atsnl-emea.azure.dataplanes.pro
