# TIBCO Platform v1.16.0 Installation Scripts

This directory contains all necessary scripts, configuration files, and values for deploying TIBCO Platform Control Plane v1.16.0 on Azure Kubernetes Service (AKS).

## Directory Structure

```
v1.16.0-cpdp-install/
├── aks-env-variables-dp1.sh          # Main environment variables file
├── values/
│   ├── cp1-values.yaml               # Control Plane helm values
│   ├── postgresql-values.yaml        # PostgreSQL configuration
│   └── maildev-deployment.yaml       # MailDev SMTP server
└── README.md                         # This file
```

## Quick Start

### 1. Configure Environment Variables

Edit and source the environment variables file:

```bash
cd /Users/kul/git/tib/workshop-tp-aks/scripts/v1.16.0-cpdp-install

# Edit credentials if needed
vi aks-env-variables-dp1.sh

# Source the file
source aks-env-variables-dp1.sh

# Verify variables are set
env | grep TP_
```

### 2. Verify Prerequisites

Ensure the following are deployed and running:
- ✅ AKS cluster (Kubernetes 1.32.6+)
- ✅ Traefik Ingress Controller (in ingress-system namespace)
- ✅ Cert-Manager (for TLS certificates)
- ✅ External-DNS (for automatic DNS record creation)
- ✅ PostgreSQL (in tibco-ext namespace)
- ✅ Elasticsearch (in elastic-system namespace, optional)
- ✅ MailDev (in tibco-ext namespace, optional)

### 3. Create Namespace and RBAC

```bash
# Create Control Plane namespace
kubectl create namespace cp1-ns

# Create service account
kubectl create serviceaccount cp1-sa -n cp1-ns

# Create ClusterRoleBinding (adjust as needed for your security requirements)
kubectl create clusterrolebinding cp1-sa-admin \
  --clusterrole=cluster-admin \
  --serviceaccount=cp1-ns:cp1-sa
```

### 4. Create Secrets

```bash
# Container Registry Secret
kubectl create secret docker-registry tibco-container-registry-credentials \
  -n cp1-ns \
  --docker-server="${TP_CONTAINER_REGISTRY}" \
  --docker-username="${TP_CONTAINER_REGISTRY_USERNAME}" \
  --docker-password="${TP_CONTAINER_REGISTRY_PASSWORD}" \
  --docker-email="${TP_CONTAINER_REGISTRY_EMAIL}"

# Database Secret
kubectl create secret generic cp-db-secret \
  -n cp1-ns \
  --from-literal=username="${TP_POSTGRES_USERNAME}" \
  --from-literal=password="${TP_POSTGRES_PASSWORD}"

# Encryption Secret
kubectl create secret generic cporch-encryption-secret \
  -n cp1-ns \
  --from-literal=CP_ENCRYPTION_SECRET="${CP_ENCRYPTION_SECRET}"
```

### 5. Add Helm Repository

```bash
# Add TIBCO Platform helm chart repository
helm repo add tibco-platform https://tibcosoftware.github.io/tp-helm-charts
helm repo update

# Verify available charts
helm search repo tibco-platform/tibco-cp --versions | head -10
```

### 6. Install Control Plane Base

```bash
# Install Control Plane Base
helm install tibco-cp-base tibco-platform/tibco-cp-base \
  --version 1.16.0 \
  -n cp1-ns \
  -f values/cp1-values.yaml \
  --timeout 20m \
  --wait

# Verify installation
kubectl get pods -n cp1-ns
```

### 7. Install Capabilities

#### BusinessWorks (BW)
```bash
helm install tibco-cp-bw tibco-platform/tibco-cp-bw \
  --version 1.16.0 \
  -n cp1-ns \
  -f values/cp1-values.yaml \
  --timeout 10m
```

#### Flogo
```bash
helm install tibco-cp-flogo tibco-platform/tibco-cp-flogo \
  --version 1.16.0 \
  -n cp1-ns \
  -f values/cp1-values.yaml \
  --timeout 10m
```

#### Developer Hub
```bash
helm install tibco-cp-devhub tibco-platform/tibco-cp-devhub \
  --version 1.16.0 \
  -n cp1-ns \
  -f values/cp1-values.yaml \
  --timeout 10m
```

#### Hawk (Monitoring)
```bash
helm install tibco-cp-hawk tibco-platform/tibco-cp-hawk \
  --version 1.16.6 \
  -n cp1-ns \
  -f values/cp1-values.yaml \
  --timeout 10m
```

#### Messaging
```bash
helm install tibco-cp-messaging tibco-platform/tibco-cp-messaging \
  --version 1.15.31 \
  -n cp1-ns \
  -f values/cp1-values.yaml \
  --timeout 10m
```

### 8. Verify Installation

```bash
# Check all pods are running
kubectl get pods -n cp1-ns

# Check ingress routes
kubectl get ingress -n cp1-ns

# Check services
kubectl get svc -n cp1-ns

# Check PVCs
kubectl get pvc -n cp1-ns

# Check helm releases
helm list -n cp1-ns
```

### 9. Access Control Plane

```bash
# Get admin password (auto-generated in v1.16.0)
kubectl get secret tp-cp-web-server -n cp1-ns -o jsonpath='{.data.TSC_ADMIN_PASSWORD}' | base64 -d

# Access Control Plane Admin Console
# URL: https://admin.dp1.atsnl-emea.azure.dataplanes.pro
# Username: admin@tibco.com (or value from CP_ADMIN_EMAIL)
# Password: (from above command or CP_ADMIN_PASSWORD env var)
```

## Configuration Reference

### Environment Variables

Key environment variables configured in `aks-env-variables-dp1.sh`:

| Variable | Value | Description |
|----------|-------|-------------|
| `TP_VERSION` | 1.16.0 | TIBCO Platform version |
| `CP_INSTANCE_ID` | cp1 | Control Plane instance identifier |
| `CP_NAMESPACE` | cp1-ns | Kubernetes namespace |
| `TP_BASE_DNS_DOMAIN` | dp1.atsnl-emea.azure.dataplanes.pro | Base DNS domain |
| `CP_MY_DNS_DOMAIN` | admin.dp1.atsnl-emea.azure.dataplanes.pro | Admin console URL |
| `CP_AI_DNS_DOMAIN` | ai.dp1.atsnl-emea.azure.dataplanes.pro | AI services URL |
| `INGRESS_CONTROLLER` | traefik | Ingress controller type |
| `TP_POSTGRES_HOST` | postgresql.tibco-ext.svc.cluster.local | PostgreSQL host |
| `TP_FILE_STORAGE_CLASS` | azure-files-sc | Storage class for PVCs |

### Helm Values

Control Plane values are defined in `values/cp1-values.yaml`:

- **Container Registry**: csgprdusw2reposaas.jfrog.io
- **Database**: In-cluster PostgreSQL (tibco-ext namespace)
- **Ingress**: Traefik with automatic TLS
- **Storage**: Azure Files (10Gi RWX)
- **Hybrid Connectivity**: Enabled for AI services
- **MCP Servers**: Enabled for BW and Flogo
- **Logging**: Elasticsearch integration
- **Email**: MailDev SMTP server

## Cluster Information

### Target Cluster
- **Name**: dp1-aks-aauk-kul
- **Environment**: ATSBNL EMEA Presales
- **Kubernetes Version**: 1.32.6
- **Azure Region**: westeurope
- **Resource Group**: kul-atsbnl

### Network Configuration
- **VNET CIDR**: 10.4.0.0/16
- **Service CIDR**: 10.0.0.0/16
- **Pod CIDR**: 10.4.0.0/20
- **Ingress LoadBalancer IP**: 40.114.164.16

## DNS Configuration

### Required DNS Records

Create the following A records in Azure DNS Zone `atsnl-emea.azure.dataplanes.pro`:

```
admin.dp1    →  40.114.164.16   (Admin Console)
ai.dp1       →  40.114.164.16   (AI Services - NEW in v1.16.0)
*.dp1        →  40.114.164.16   (Wildcard for Data Plane apps)
```

External-DNS can create these automatically if configured.

## Troubleshooting

### Common Issues

#### 1. Pods not starting
```bash
# Check pod events
kubectl describe pod <pod-name> -n cp1-ns

# Check pod logs
kubectl logs <pod-name> -n cp1-ns

# Check image pull secrets
kubectl get secrets -n cp1-ns | grep docker-registry
```

#### 2. Ingress not accessible
```bash
# Check ingress status
kubectl get ingress -n cp1-ns

# Verify DNS resolution
nslookup admin.dp1.atsnl-emea.azure.dataplanes.pro

# Check Traefik logs
kubectl logs -n ingress-system -l app.kubernetes.io/name=traefik
```

#### 3. Database connection issues
```bash
# Test PostgreSQL connectivity
kubectl run psql-test --rm -it --image=postgres:15 -n cp1-ns -- \
  psql -h postgresql.tibco-ext.svc.cluster.local -U postgres -d postgres

# Check database secret
kubectl get secret cp-db-secret -n cp1-ns -o yaml
```

#### 4. Helm release failed
```bash
# Check helm release status
helm status tibco-cp-base -n cp1-ns

# View helm release history
helm history tibco-cp-base -n cp1-ns

# Get detailed helm values
helm get values tibco-cp-base -n cp1-ns
```

### Debug Commands

```bash
# Get all resources in namespace
kubectl get all -n cp1-ns

# Check events
kubectl get events -n cp1-ns --sort-by='.lastTimestamp'

# View logs for all pods
kubectl logs -n cp1-ns -l app.kubernetes.io/name=tibco-cp --tail=100

# Port-forward to a service
kubectl port-forward -n cp1-ns svc/cp-router 8080:80
```

## Upgrade from v1.15.0

If upgrading from v1.15.0, see the upgrade guide:
[Upgrade Guide v1.15.0 to v1.16.0](/howto/v1.16/UPGRADE-1.15-TO-1.16.md)

### Key Changes
- Container registry URL changed
- New AI services endpoint (`ai.` subdomain)
- MCP servers enabled by default
- Hybrid connectivity enabled

## Additional Resources

- **Official Documentation**: [TIBCO Platform Helm Charts](https://github.com/TIBCOSoftware/tp-helm-charts)
- **Release Notes**: [v1.16.0 Release Notes](/releases/v1.16.0.md)
- **Setup Guide**: [Complete AKS Setup Guide](/howto/v1.16/how-to-cp-and-dp-aks-setup-guide.md)
- **Architecture**: [Platform Architecture Diagrams](/docs/diagrams/)

## Support

For issues or questions:
1. Check [Troubleshooting Guide](/docs/troubleshooting-v1.16.md)
2. Review [Known Issues](/releases/v1.16.0.md#known-issues--workarounds)
3. Check TIBCO Community forums
4. Contact TIBCO Support

---

**Last Updated**: April 10, 2026  
**TIBCO Platform Version**: 1.16.0  
**Status**: Production Ready ✅
