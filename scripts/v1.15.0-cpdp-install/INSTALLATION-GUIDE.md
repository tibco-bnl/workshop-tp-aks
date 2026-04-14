# TIBCO Platform Control Plane Installation Guide
## Version 1.15.0 on Azure AKS
## Cluster: dp1-aks-aauk-kul

---

## ⚠️ CRITICAL v1.15.0 Changes

### Auto-Generated Admin Password

**v1.15 now AUTO-GENERATES the admin password** instead of using a user-defined password.

**Key Changes from v1.14:**
- ❌ **REMOVED**: `adminInitialPassword` parameter (no longer supported)
- ❌ **REMOVED**: `enable_api_based_initialization` parameter (always enabled in v1.15)
- ✅ **NEW**: Password stored in secret `tp-cp-web-server` with key `TSC_ADMIN_PASSWORD`
- ✅ **NEW**: Retrieve password AFTER deployment using `06-get-admin-password.sh`

**Why This Matters:**
If you include the old v1.14 parameters (`adminInitialPassword`, `enable_api_based_initialization`) in your values file, it will cause:
- Incomplete database initialization
- Missing team membership
- Login failures with "User is NOT associated with any accounts"

**Corrected values/cp1-values.yaml:**
```yaml
global:
  external:
    # ✅ CORRECT - Admin config WITHOUT password
    admin:
      customerID: "dp1-customer"
      email: "admin@tibco.com"
      firstname: "Platform"
      lastname: "Admin"
    
    # ❌ WRONG - Do NOT include these:
    # adminInitialPassword: "Welcome123!"
    # enable_api_based_initialization: true
```

---

## Installation Sequence

Execute the scripts in the following order. Each script is prefixed with a number indicating its sequence.

### Phase 0: Pre-Installation (Ingress Migration)

**00a-nginx-to-traefik-migration/**
- **Purpose**: Migrate from NGINX Ingress to Traefik (if previously using NGINX)
- **Status**: Optional - Only needed if migrating from NGINX
- **Contents**: Scripts and documentation for ingress migration

### Phase 1: Infrastructure Setup

**01-update-ingress.sh**
- **Purpose**: Install/Update Traefik ingress controller
- **What it does**:
  - Installs Traefik Helm chart
  - Configures LoadBalancer service
  - Sets up ingress class
- **Prerequisites**: None
- **Run**: `./01-update-ingress.sh`

**01d-fix-external-dns.sh**
- **Purpose**: Configure External DNS (if applicable)
- **Status**: Optional - Only if using External DNS
- **Run**: `./01d-fix-external-dns.sh`

### Phase 2: Observability

**02-upgrade-prometheus.sh**
- **Purpose**: Install/Upgrade kube-prometheus-stack
- **What it does**:
  - Installs Prometheus Operator
  - Installs Grafana
  - Configures monitoring
  - Creates Traefik ingresses for Prometheus/Grafana
- **Prerequisites**: 01-update-ingress.sh completed
- **Run**: `./02-upgrade-prometheus.sh`

**03-verify-observability.sh**
- **Purpose**: Verify Prometheus and Grafana are working
- **Run**: `./03-verify-observability.sh`

### Phase 3: Control Plane Prerequisites

Prerequisites are now separated into individual steps for granular control:

**03a-create-namespace-and-rbac.sh**
- **Purpose**: Create CP namespace, service account, and label ingress namespace
- **What it does**:
  - Creates cp1-ns namespace with proper labels
  - Creates cp1-sa service account
  - Labels ingress-system namespace
  - Creates container registry secret in cp1-ns
- **Prerequisites**: None
- **Run**: `./03a-create-namespace-and-rbac.sh`

**03b-install-postgresql.sh**
- **Purpose**: Install PostgreSQL in tibco-ext namespace
- **What it does**:
  - Creates tibco-ext namespace
  - Installs PostgreSQL using Bitnami Helm chart
  - Uses values from `values/postgresql-values.yaml`
  - Configures 50Gi persistent storage
- **Prerequisites**: None
- **Values File**: `values/postgresql-values.yaml`
- **Run**: `./03b-install-postgresql.sh`

**Clean PostgreSQL (if needed):**
```bash
helm uninstall postgresql -n tibco-ext
kubectl delete pvc data-postgresql-0 -n tibco-ext
```

**03c-install-maildev.sh**
- **Purpose**: Install MailDev email server for testing
- **What it does**:
  - Deploys MailDev in tibco-ext namespace
  - Creates ingress at https://mail.dp1.atsnl-emea.azure.dataplanes.pro
  - Exposes SMTP on port 1025
- **Prerequisites**: None
- **Manifest**: `values/maildev-deployment.yaml`
- **Run**: `./03c-install-maildev.sh`

**03d-create-secrets.sh**
- **Purpose**: Create all required Kubernetes secrets
- **What it does**:
  - Generates and creates session-keys secret (TSC_SESSION_KEY, DOMAIN_SESSION_KEY, SESSION_KEY, SESSION_IV)
  - Generates and creates cporch-encryption-secret (CP_ENCRYPTION_SECRET, CPORCH_ENCRYPTION_KEY)
  - Creates postgresql secret reference
- **Prerequisites**: 03a-create-namespace-and-rbac.sh completed
- **Run**: `./03d-create-secrets.sh`

**03a-configure-coredns.sh** ⭐ **IMPORTANT**
- **Purpose**: Configure CoreDNS for internal DNS resolution
- **What it does**:
  - Adds custom DNS rewrite rule for dp1.atsnl-emea.azure.dataplanes.pro
  - Rewrites *.dp1... to traefik.ingress-system.svc.cluster.local
  - Restarts CoreDNS pods
  - Verifies DNS resolution
- **Why this is critical**: Fixes OAuth callback issues by preventing hairpin NAT
- **Prerequisites**: 01-update-ingress.sh completed (Traefik must exist)
- **Run**: `./03a-configure-coredns.sh`

### Phase 4: Control Plane Installation

**04a-cleanup-databases.sh** (Optional - For Fresh Start)
- **Purpose**: Drop all cp1_* databases for clean reinstallation
- **When to use**: 
  - After uninstalling CP for fresh deployment
  - When database schema is corrupted
  - When migrating from incorrect v1.14 parameters
  - **When host_prefix conflict occurs**
- **What it does**:
  - Drops all cp1_* databases (9 databases total)
  - Confirms with user before deletion
  - Prepares for fresh CP deployment
- **⚠️ WARNING**: This deletes ALL data in CP databases
- **Run**: `./04a-cleanup-databases.sh`

**05-install-controlplane.sh** (renamed from 04-install-controlplane.sh)
- **Purpose**: Install TIBCO Platform Control Plane
- **What it does**:
  - Validates all prerequisites (namespace, PostgreSQL, MailDev, secrets)
  - Installs tibco-cp-base Helm chart (version 1.15.0)
  - Uses values from `values/cp1-values.yaml`
  - Creates admin user: admin@tibco.com with AUTO-GENERATED password
  - Deploys all CP components
  - Initializes databases with correct schema
- **Prerequisites**: 
  - 03a-create-namespace-and-rbac.sh completed
  - 03b-install-postgresql.sh completed
  - 03c-install-maildev.sh completed
  - 03d-create-secrets.sh completed
  - 03a-configure-coredns.sh completed ⭐
  - (Optional) 04a-cleanup-databases.sh if redeploying
- **Values File**: `values/cp1-values.yaml`
- **Run**: `./05-install-controlplane.sh`

**Manual Installation Option:**
```bash
# If you prefer to run helm manually:
helm upgrade --install --wait --timeout 20m -n cp1-ns tibco-cp-base \
  tibco-platform/tibco-cp-base \
  --version "1.15.0" \
  --values values/cp1-values.yaml
```

**06-get-admin-password.sh** ⭐ **REQUIRED AFTER DEPLOYMENT**
- **Purpose**: Retrieve auto-generated admin password from v1.15
- **What it does**:
  - Extracts password from secret `tp-cp-web-server`
  - Displays login credentials
  - Shows admin console URL
- **When to run**: AFTER CP deployment completes successfully
- **Prerequisites**: 04-install-controlplane.sh completed
- **Run**: `./06-get-admin-password.sh`

**Expected Output:**
```
========================================
  Control Plane Login Credentials
========================================

  URL:      https://admin.dp1.atsnl-emea.azure.dataplanes.pro
  Username: admin@tibco.com
  Password: <auto-generated-password>

========================================
```

**04b-provision-console-subscription.sh**
- **Purpose**: Manually provision Platform Console subscription via API
- **Status**: Optional - Auto-provision happens on first browser login
- **When to use**: If API-based provisioning is enabled
- **Run**: `./04b-provision-console-subscription.sh`

### Phase 5: Data Plane Installation

**05-install-dataplane.sh**
- **Purpose**: Install TIBCO Platform Data Plane
- **Prerequisites**: 04-install-controlplane.sh completed
- **Run**: `./05-install-dataplane.sh`

### Phase 6: Post-Installation

**06-post-install-verification.sh**
- **Purpose**: Verify entire installation
- **What it checks**:
  - All pods running
  - Ingresses configured
  - Services accessible
  - DNS resolution working
- **Run**: `./06-post-install-verification.sh`

---

## Configuration Files

### Environment Configuration

**aks-env-variables-dp1.sh**
- Global environment variables for the cluster
- Contains:
  - Cluster information
  - DNS domains
  - Storage classes
  - Container registry credentials
  - Database connection details
- **Usage**: Source this file before running scripts
  ```bash
  source aks-env-variables-dp1.sh
  ```

### Helm Values Files (in `values/` directory)

**values/cp1-values.yaml**
- Main Control Plane configuration
- Key settings:
  - Admin user: admin@tibco.com
  - Admin password: Welcome123!
  - DNS domain: dp1.atsnl-emea.azure.dataplanes.pro
  - PostgreSQL: postgresql.tibco-ext.svc.cluster.local
  - MailDev SMTP: development-mailserver.tibco-ext.svc.cluster.local
  - API-based provisioning: false (auto-provision on browser login)

**values/maildev-deploy.yaml**
- Standalone MailDev deployment (already deployed via 03-setup-cp-prerequisites.sh)

---

## Quick Start Guide

### 1. Prerequisites Check
```bash
# Verify kubectl access
kubectl get nodes

# Verify Helm is installed
helm version

# Source environment variables
source aks-env-variables-dp1.sh
```

### 2. Complete Installation (All Phases)
```bash
# Phase 1: Infrastructure
./01-update-ingress.sh

# Phase 2: Observability
./02-upgrade-prometheus.sh
./03-verify-observability.sh

# Phase 3: Prerequisites & DNS
./03-setup-cp-prerequisites.sh
./03a-configure-coredns.sh  # ⭐ CRITICAL - Fixes OAuth callbacks

# Phase 4: Control Plane
./04-install-controlplane.sh

# Verify installation
kubectl get pods -n cp1-ns
```

### 3. Access Control Plane
```bash
# URL
https://admin.dp1.atsnl-emea.azure.dataplanes.pro

# Credentials
Email: admin@tibco.com
Password: Tibco123!

# Note: First login will auto-provision Platform Console subscription
```

### 4. Access MailDev (Email Testing)
```bash
https://mail.dp1.atsnl-emea.azure.dataplanes.pro
```

---

## Important Notes

### ⭐ CoreDNS Configuration is Critical!

The `03a-configure-coredns.sh` script **MUST** be run before accessing the admin console. This fixes OAuth callback issues by:

1. Rewriting `*.dp1.atsnl-emea.azure.dataplanes.pro` to `traefik.ingress-system.svc.cluster.local`
2. Ensuring internal pods resolve the domain to Traefik's ClusterIP (10.0.59.87)
3. Preventing hairpin NAT issues with external LoadBalancer (20.54.225.126)

**Without this configuration**, you will get:
- "Internal Server Error" on login
- "User is NOT associated with any accounts" errors
- OAuth callback failures

### Admin User & Subscription

- **Admin Email**: admin@tibco.com
- **Initial Password**: Welcome123! (must change on first login)
- **Subscription Provisioning**: Automatic on first browser login (API-based provisioning is disabled)

### DNS & Ingress

- **External LoadBalancer IP**: 20.54.225.126
- **Traefik ClusterIP**: 10.0.59.87
- **kube-dns ClusterIP**: 10.0.0.10
- **Admin URL**: https://admin.dp1.atsnl-emea.azure.dataplanes.pro
- **MailDev URL**: https://mail.dp1.atsnl-emea.azure.dataplanes.pro

### Certificates

- **Current**: Traefik default cert (self-signed)
- **Let's Encrypt**: HTTP-01 validation blocked by Traefik HTTP→HTTPS:8443 redirect
- **Browser**: Accept certificate warning temporarily

### PostgreSQL

- **Namespace**: tibco-ext (shared)
- **Host**: postgresql.tibco-ext.svc.cluster.local:5432
- **Username**: postgres
- **Password**: postgres
- **Databases**: 9 databases auto-created (cp1_defaultidpdb, cp1_orchestratordb, etc.)
- **Storage**: 50Gi on azurefile-csi-premium
- **Access**: Internal only (ClusterIP service)

### Storage Classes

- **File Storage**: azurefile-csi-premium (RWX)
- **Disk Storage**: managed-csi-premium (RWO)

---

## Troubleshooting

### Login Issues

**Symptom**: "Internal Server Error" or "User not authorized"

**Solution**:
1. Verify CoreDNS configuration: `./03a-configure-coredns.sh`
2. Test DNS resolution:
   ```bash
   kubectl run dns-test -n default --image=busybox --rm -i --restart=Never -- \
     nslookup admin.dp1.atsnl-emea.azure.dataplanes.pro
   # Should resolve to traefik.ingress-system.svc.cluster.local
   ```
3. Check CoreDNS pods: `kubectl get pods -n kube-system -l k8s-app=kube-dns`

### Pod Failures

**Check pod status**:
```bash
kubectl get pods -n cp1-ns
kubectl describe pod <pod-name> -n cp1-ns
kubectl logs <pod-name> -n cp1-ns
```

**Common issues**:
- ImagePullBackOff: Check registry credentials in values/cp1-values.yaml
- CrashLoopBackOff: Check logs for startup errors
- Pending: Check PVC status

### Database Connection Issues

**Test PostgreSQL connectivity**:
```bash
kubectl run pg-test -n cp1-ns --image=postgres:16-alpine --rm -i \
  --env="PGPASSWORD=postgres" -- \
  psql -h postgresql.tibco-ext.svc.cluster.local -U postgres -d postgres -c "SELECT version();"
```

### MailDev Access Issues

**Fix routing priority**:
```bash
# MailDev should have higher priority than CP router wildcard
kubectl annotate ingress maildev-ingress -n tibco-ext \
  traefik.ingress.kubernetes.io/router.priority="100" --overwrite

kubectl annotate ingress router -n cp1-ns \
  traefik.ingress.kubernetes.io/router.priority="10" --overwrite
```

---

## File Structure

```
v1.15.0-cpdp-install/
├── 00a-nginx-to-traefik-migration/    # Optional: NGINX to Traefik migration
├── 01-update-ingress.sh                # Install/update Traefik
├── 01d-fix-external-dns.sh             # Optional: External DNS
├── 02-upgrade-prometheus.sh            # Install observability stack
├── 03-verify-observability.sh          # Verify Prometheus/Grafana
├── 03-setup-cp-prerequisites.sh        # ⭐ Install all CP prerequisites
├── 03a-configure-coredns.sh            # ⭐ CRITICAL: Configure DNS rewrites
├── 04-install-controlplane.sh          # Install Control Plane
├── 04b-provision-console-subscription.sh # Optional: Manual subscription provisioning
├── 05-install-dataplane.sh             # Install Data Plane
├── 06-post-install-verification.sh     # Verify installation
├── aks-env-variables-dp1.sh            # Environment variables
├── values/
│   ├── cp1-values.yaml                 # ⭐ Control Plane Helm values
│   └── maildev-deploy.yaml             # MailDev deployment
├── backups/                            # Backup configurations
├── INSTALLATION-GUIDE.md               # ⭐ This file
└── README.md                           # Quick reference

⭐ = Critical files
```

---

## Support & Documentation

- **Workshop Docs**: [GitHub - TIBCOSoftware/tp-helm-charts](https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/docs/workshop/aks/control-plane)
- **Official Charts**: [TIBCO Platform Helm Charts](https://github.com/TIBCOSoftware/tp-helm-charts)
- **TIBCO Documentation**: Check TIBCO Platform documentation for version 1.15.0

---

**Installation Date**: March 23, 2026  
**Cluster**: dp1-aks-aauk-kul (westeurope)  
**Kubernetes Version**: 1.32.6  
**TIBCO Platform Version**: 1.15.0
