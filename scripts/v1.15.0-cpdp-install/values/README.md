# Values Files Directory

This directory contains all configuration files (values files and manifests) for the TIBCO Platform Control Plane installation.

## Files

### Control Plane Configuration

**cp1-values.yaml**
- **Purpose**: Main Helm values file for tibco-cp-base chart
- **Used by**: `05-install-controlplane.sh`
- **Key configurations**:
  - Admin user: admin@tibco.com (password auto-generated in v1.15)
  - DNS domain: dp1.atsnl-emea.azure.dataplanes.pro
  - Static subscription URL: benelux.dp1.atsnl-emea.azure.dataplanes.pro
  - PostgreSQL: postgresql.tibco-ext.svc.cluster.local
  - SMTP: development-mailserver.tibco-ext.svc.cluster.local:1025
  - Hybrid connectivity: disabled
  - Single namespace mode: enabled

**Important v1.15.0 changes:**
- ❌ No `adminInitialPassword` (auto-generated)
- ❌ No `enable_api_based_initialization` (always enabled)
- ✅ Password stored in secret `tp-cp-web-server`

### PostgreSQL Configuration

**postgresql-values.yaml**
- **Purpose**: Bitnami PostgreSQL Helm chart values
- **Used by**: `03b-install-postgresql.sh`
- **Chart**: bitnami/postgresql ^16.0.0
- **Namespace**: tibco-ext
- **Key configurations**:
  - Image: csgprdeuwrepoedge.jfrog.io/tibco-platform-docker-prod/common-postgresql:16.4.0
  - Database: postgres
  - User: postgres
  - Password: postgres
  - Storage: 50Gi on managed-csi-premium (Azure Disk)
  - Resources: 500m CPU, 1Gi RAM (requests) / 2 CPU, 4Gi RAM (limits)

### MailDev Configuration

**maildev-deployment.yaml**
- **Purpose**: Kubernetes manifest for MailDev email testing server
- **Used by**: `03c-install-maildev.sh`
- **Namespace**: tibco-ext
- **Components**:
  - Deployment: maildev with 1 replica
  - Service: ClusterIP on ports 1025 (SMTP) and 1080 (Web UI)
  - Ingress: https://mail.dp1.atsnl-emea.azure.dataplanes.pro
- **Key configurations**:
  - Image: maildev/maildev:latest
  - Resources: 50m CPU, 128Mi RAM (requests) / 200m CPU, 256Mi RAM (limits)
  - TLS: Let's Encrypt via cert-manager

## Usage

These files are automatically used by the corresponding installation scripts. You can modify them before running the scripts to customize your installation.

### Customization Examples

**Change PostgreSQL storage size:**
```yaml
# Edit postgresql-values.yaml
primary:
  persistence:
    size: "100Gi"  # Change from 50Gi to 100Gi
```

**Change admin email:**
```yaml
# Edit cp1-values.yaml
admin:
  email: "your-admin@example.com"  # Change from admin@tibco.com
```

**Change DNS domain:**
```yaml
# Edit cp1-values.yaml
dnsDomain: "your-domain.example.com"

# Also update in maildev-deployment.yaml
spec:
  rules:
    - host: mail.your-domain.example.com
```

## File Lifecycle

- **Before installation**: Review and customize these files
- **During installation**: Scripts use these files to deploy components
- **After installation**: Keep these files for reference and future upgrades

## Version Control

These files are version-controlled and should be updated when:
- Upgrading to a new TIBCO Platform version
- Changing infrastructure configurations
- Modifying DNS domains or resource allocations

## See Also

- [INSTALLATION-GUIDE.md](../INSTALLATION-GUIDE.md) - Complete installation guide
- [ROOT-CAUSE-ANALYSIS.md](../ROOT-CAUSE-ANALYSIS.md) - v1.15.0 breaking changes analysis
