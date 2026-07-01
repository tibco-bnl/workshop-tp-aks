---
layout: default
title: TIBCO Platform Control Plane and Data Plane Setup on AKS
---

# TIBCO Platform Control Plane and Data Plane Setup on AKS

**Document Purpose**: Complete step-by-step guide for deploying TIBCO Platform Control Plane and Data Plane on the same Azure Kubernetes Service (AKS) cluster.

**Target Audience**: DevOps engineers, Platform administrators

**Prerequisites**: Review [prerequisites-checklist-for-customer](./prerequisites-checklist-for-customer) before starting

**Estimated Time**: 4-6 hours (first-time installation)

**Last Updated**: June 11, 2026

> **Version note:** This is the shared AKS CP+DP baseline guide and contains the captured 1.16.0 environment examples used by this workshop. It now includes compatibility notes for the current 1.18.0 release. For release-specific changes, start with the versioned guides: [v1.16](./v1.16/how-to-cp-and-dp-aks-setup-guide), [v1.17](./v1.17/how-to-cp-and-dp-aks-setup-guide), or [v1.18](./v1.18/how-to-cp-and-dp-aks-setup-guide).

**Configuration Files**:
- Generic template: `scripts/aks-env-variables.sh`
- dp1-aks-aauk-kul cluster: `scripts/v1.16.0-cpdp-install/aks-env-variables-dp1.sh`

---

> **Using an Existing Cluster?**  
> This guide covers both new cluster creation and installation on existing clusters. If you already have an AKS cluster with ingress controller, observability stack, and storage configured (like **dp1-aks-aauk-kul**), you can skip Parts 2-7 and jump directly to [Part 8: Control Plane Deployment](#part-8-control-plane-deployment). Use the pre-configured environment file `scripts/v1.16.0-cpdp-install/aks-env-variables-dp1.sh` for existing cluster configurations.

---

## Table of Contents

- [Overview](#overview)
- [Release-Specific Notes](#release-specific-notes)
- [Architecture](#architecture)
- [Part 1: Environment Preparation](#part-1-environment-preparation)
- [Part 2: AKS Cluster Setup](#part-2-aks-cluster-setup)
- [Part 3: Storage Configuration](#part-3-storage-configuration)
- [Part 4: Ingress Controller Setup](#part-4-ingress-controller-setup)
- [Part 5: PostgreSQL Database Setup](#part-5-postgresql-database-setup)
- [Part 6: DNS Configuration](#part-6-dns-configuration)
- [Part 7: Certificate Management](#part-7-certificate-management)
- [Part 8: Control Plane Deployment](#part-8-control-plane-deployment)
- [Part 9: Data Plane Deployment](#part-9-data-plane-deployment)
- [Part 10: Post-Deployment Verification](#part-10-post-deployment-verification)
- [Part 11: Troubleshooting](#part-11-troubleshooting)

---

## Overview

This guide walks through deploying both TIBCO Platform Control Plane and Data Plane on a single AKS cluster. This is the recommended approach for development, testing, and single-region production deployments.

### What You Will Deploy

- **Azure Kubernetes Service (AKS)** cluster with 3+ nodes (or use existing cluster)
- **Storage Classes** for Azure Disk and Azure Files
- **Ingress Controller** (Traefik recommended, NGINX deprecated)
- **Azure Database for PostgreSQL Flexible Server** (or in-cluster PostgreSQL for dev/test)
- **TIBCO Platform Control Plane** (current release: 1.18.0; archived overlays for older releases)
- **TIBCO Platform Data Plane** with capabilities (BWCE, Flogo, EMS)

### Communication Architecture

**Important**: Control Plane and Data Plane communicate via **secure tunnels over DNS entries**, NOT VNet peering:
- Data Plane connects to Control Plane's `my` domain (API endpoint)
- Data Plane establishes secure tunnel via Control Plane's `tunnel` domain
- BWCE and Flogo applications use ingress controllers registered in DNS for external access
- VNet peering is **OPTIONAL** and only needed for private/internal-only scenarios

---

## Release-Specific Notes

This guide keeps a common AKS installation flow while the versioned overlays capture release details. Check the following points before using the shared examples for 1.18.0:

- **Email server settings**: In 1.18.0, email server configuration moved out of Control Plane Helm values and into Platform Console. Do not include the deprecated `global.external.emailServerType`, `global.external.emailServer`, `global.external.fromAndReplyToEmailAddress`, `global.external.cronJobReportsEmailAlias`, or `global.external.platformEmailNotificationCcAddresses` fields in 1.18.0 values files.
- **Upgrade assistant**: The 1.18.0 Helm scripts include `scripts/1.18.0/upgrade.sh` for 1.17.0 to 1.18.0 Control Plane upgrades. It validates the deployed version, requires Bash 4+, Helm 3.17+, yq 4.45.4+, jq 1.8+, and removes the deprecated email fields during values generation.
- **Gateway API**: 1.18.0 adds Gateway API endpoint support for BW5, BW6, Flogo, Developer Hub, and observability-related resources. If you choose Gateway API instead of ingress, validate that the Gateway API CRDs, GatewayClass, Gateway, listeners, and HTTPRoutes exist before provisioning capabilities.
- **Namespace-level RBAC**: 1.18.0 adds namespace-aware permissions for Data Plane application deployments. Make sure Application Manager/Application Viewer assignments match the namespaces where capabilities and applications will run.
- **Simplified DNS**: The simplified DNS model remains applicable for 1.18.0. Use one Control Plane base domain when possible, for example `platform.azure.example.com`, with URLs such as `admin.platform.azure.example.com` and `<subscription-host-prefix>.platform.azure.example.com`. In this mode, set `dnsDomain` and `dnsTunnelDomain` to the same value; hybrid tunnel traffic is routed by path under `/infra/tunnel` instead of requiring a second `cp1-tunnel` wildcard domain.

---

## Architecture

```mermaid
graph TB
    subgraph "Azure Cloud"
        subgraph "AKS Cluster"
            subgraph "Control Plane Namespace"
                CP[TIBCO Control Plane]
                CP_DB[(PostgreSQL)]
            end
            
            subgraph "Data Plane Namespace"
                DP[TIBCO Data Plane]
                BWCE[BWCE Runtime]
                FLOGO[Flogo Runtime]
                EMS[EMS Runtime]
            end
            
            subgraph "Infrastructure"
                INGRESS[Ingress Controller<br/>Traefik/NGINX]
                STORAGE[Azure Storage<br/>Disk + Files]
            end
        end
        
        LB[Azure Load Balancer]
        DNS[Azure DNS]
        PSQL[Azure PostgreSQL<br/>Flexible Server]
    end
    
    USER[Users/Apps] -->|HTTPS| LB
    LB -->|443| INGRESS
    INGRESS -->|my.domain| CP
    INGRESS -->|tunnel.domain| CP
    INGRESS -->|app.domain| BWCE
    INGRESS -->|app.domain| FLOGO
    
    DP -.->|Secure Tunnel<br/>via DNS| CP
    CP -->|5432| PSQL
    CP -->|PVC| STORAGE
    DP -->|PVC| STORAGE
    
    DNS -.->|Wildcard Records<br/>*.base-domain| LB
```

---

## Part 1: Environment Preparation

### Step 1.1: Install Required Tools

Ensure all required tools are installed:

```bash
# Check Azure CLI
az --version
# Required: 2.50.0+

# Check kubectl
kubectl version --client
# Required: Latest stable

# Check Helm
helm version
# Required: 3.17.0+

# Check openssl
openssl version
# Required: 1.1+
```

### Step 1.2: Set Environment Variables

Source the environment variables script:

```bash
# Navigate to the workshop directory
cd /path/to/workshop-tp-aks

# For new installations, source the generic template:
source scripts/aks-env-variables.sh

# For existing dp1-aks-aauk-kul cluster (ATSBNL):
source scripts/v1.16.0-cpdp-install/aks-env-variables-dp1.sh

# Verify variables are set
echo "Azure Region: $TP_AZURE_REGION"
echo "AKS Cluster: $TP_CLUSTER_NAME"
echo "Base DNS: $TP_BASE_DNS_DOMAIN"
echo "Control Plane Admin: $CP_MY_DNS_DOMAIN"

# Run validation
validate_prerequisites

# Display full configuration
show_config
```

**Example Configuration (Generic Template)**:

```bash
# Azure Configuration
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_REGION="eastus"
export AZURE_RESOURCE_GROUP="tibco-platform-rg"

# AKS Configuration
export AKS_CLUSTER_NAME="tibco-platform-aks"
export AKS_NODE_COUNT=3
export AKS_NODE_SIZE="Standard_D8s_v3"

# Control Plane Configuration
export TP_CP_INSTANCE_ID="cp1"
export TP_CP_NAMESPACE="cp1-ns"
export TP_BASE_DNS_DOMAIN="platform.azure.example.com"
export TP_CP_MY_DOMAIN="${TP_BASE_DNS_DOMAIN}"
export TP_CP_TUNNEL_DOMAIN="${TP_BASE_DNS_DOMAIN}"
# Resulting URLs: https://admin.${TP_BASE_DNS_DOMAIN}, https://<hostPrefix>.${TP_BASE_DNS_DOMAIN}

# Data Plane Configuration
export TP_DP_INSTANCE_ID="dp1"
export TP_DP_NAMESPACE="dp1-ns"
export TP_DP_DOMAIN="dp1.platform.azure.example.com"

# Storage Configuration
export AZURE_STORAGE_ACCOUNT="tibcoplatformsa"
export AZURE_STORAGE_RESOURCE_GROUP="$AZURE_RESOURCE_GROUP"

# Database Configuration (Azure PostgreSQL)
export POSTGRES_HOST="tibco-platform-db.postgres.database.azure.com"
export POSTGRES_PORT="5432"
export POSTGRES_DB="postgres"
export POSTGRES_USER="tibcoadmin"
export POSTGRES_PASSWORD="YourSecurePassword123!"
export POSTGRES_SSL_MODE="require"
export POSTGRES_SSL_ROOT_CERT_FILE="/path/to/azure-postgres-ca.pem"

# Container Registry
export CONTAINER_REGISTRY_USERNAME="your-username"
export CONTAINER_REGISTRY_PASSWORD="your-password"
export CONTAINER_REGISTRY_SERVER="csgprdusw2reposaas.jfrog.io"
```

**Example Configuration (dp1-aks-aauk-kul - ATSBNL Existing Cluster)**:

```bash
# Azure Configuration - Get from current Azure CLI session
export TP_SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null || echo "")
export TP_SUBSCRIPTION_NAME=$(az account show --query name -o tsv 2>/dev/null || echo "")
export TP_AZURE_REGION="westeurope"
export TP_RESOURCE_GROUP="kul-atsbnl"

# Existing AKS Cluster
export TP_CLUSTER_NAME="dp1-aks-aauk-kul"
export TP_KUBERNETES_VERSION="1.32.6"

# v1.16.0 DNS Configuration
export TP_TOP_LEVEL_DOMAIN="atsnl-emea.azure.dataplanes.pro"
export TP_SANDBOX="dp1"
export TP_BASE_DNS_DOMAIN="dp1.atsnl-emea.azure.dataplanes.pro"

# Control Plane (v1.16.0)
export CP_INSTANCE_ID="cp1"
export CP_NAMESPACE="cp1-ns"
export CP_MY_DNS_DOMAIN="admin.dp1.atsnl-emea.azure.dataplanes.pro"

# Data Plane (v1.16.0)
export DP_INSTANCE_ID="dp1"
export DP_NAMESPACE="dp1-ns"
export TP_DOMAIN="dp1.atsnl-emea.azure.dataplanes.pro"

# Ingress (Traefik - migrated from NGINX)
export TP_INGRESS_CLASS="traefik"
export INGRESS_LOAD_BALANCER_IP="20.54.225.126"

# Storage
export TP_DISK_STORAGE_CLASS="azure-disk-sc"
export TP_FILE_STORAGE_CLASS="azure-files-sc"

# Observability (Existing)
export ELASTIC_NAMESPACE="elastic-system"
export PROMETHEUS_NAMESPACE="prometheus-system"

# Database (In-cluster PostgreSQL for dev/test)
export TP_POSTGRES_HOST="postgresql.tibco-ext.svc.cluster.local"
export TP_POSTGRES_PORT="5432"
export TP_POSTGRES_DATABASE="postgres"
export TP_POSTGRES_USERNAME="postgres"

# Container Registry
export TP_CONTAINER_REGISTRY="csgprdusw2reposaas.jfrog.io"
export TP_CONTAINER_REGISTRY_USERNAME="<your-username>"
export TP_CONTAINER_REGISTRY_PASSWORD="<your-password>"
```

> **Note**: The dp1-aks-aauk-kul example shows an existing cluster with Traefik ingress controller, observability stack (Elasticsearch 8.17.3, Prometheus 48.3.4), and v1.16.0 DNS architecture. Subscriptions can have custom hostPrefix (e.g., 'ai', 'benelux') creating URLs like {hostPrefix}.dp1.atsnl-emea.azure.dataplanes.pro.

### Step 1.3: Login to Azure

```bash
# Login to Azure
az login

# Set the subscription
az account set --subscription "$AZURE_SUBSCRIPTION_ID"

# Verify the subscription
az account show --query "{Name:name, ID:id, State:state}" -o table
```

---

## Part 2: AKS Cluster Setup

### Step 2.1: Create Resource Group

```bash
# Create resource group
az group create \
  --name "$AZURE_RESOURCE_GROUP" \
  --location "$AZURE_REGION"
```

### Step 2.2: Create Virtual Network (Optional)

If you want explicit VNet control:

```bash
# Create VNet
az network vnet create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "tibco-platform-vnet" \
  --address-prefixes 10.4.0.0/16 \
  --subnet-name "aks-subnet" \
  --subnet-prefixes 10.4.0.0/20

# Get subnet ID
SUBNET_ID=$(az network vnet subnet show \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --vnet-name "tibco-platform-vnet" \
  --name "aks-subnet" \
  --query id -o tsv)

echo "Subnet ID: $SUBNET_ID"
```

### Step 2.3: Create AKS Cluster

**Option A: AKS with Azure CNI (Recommended)**

```bash
az aks create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$AKS_CLUSTER_NAME" \
  --location "$AZURE_REGION" \
  --kubernetes-version 1.32 \
  --node-count $AKS_NODE_COUNT \
  --node-vm-size "$AKS_NODE_SIZE" \
  --network-plugin azure \
  --vnet-subnet-id "$SUBNET_ID" \
  --service-cidr 10.0.0.0/16 \
  --dns-service-ip 10.0.0.10 \
  --enable-managed-identity \
  --generate-ssh-keys \
  --enable-cluster-autoscaler \
  --min-count 3 \
  --max-count 10 \
  --tags "Environment=Production" "Application=TIBCOPlatform"
```

**Option B: AKS with Kubenet (Simpler networking)**

```bash
az aks create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$AKS_CLUSTER_NAME" \
  --location "$AZURE_REGION" \
  --kubernetes-version 1.32 \
  --node-count $AKS_NODE_COUNT \
  --node-vm-size "$AKS_NODE_SIZE" \
  --network-plugin kubenet \
  --enable-managed-identity \
  --generate-ssh-keys \
  --enable-cluster-autoscaler \
  --min-count 3 \
  --max-count 10
```

**Note**: Cluster creation takes 5-10 minutes.

### Step 2.4: Get AKS Credentials

```bash
# Get credentials
az aks get-credentials \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$AKS_CLUSTER_NAME" \
  --overwrite-existing

# Verify connection
kubectl get nodes

# Expected output:
# NAME                                STATUS   ROLES   AGE   VERSION
# aks-nodepool1-12345678-vmss000000   Ready    agent   5m    v1.32.0
# aks-nodepool1-12345678-vmss000001   Ready    agent   5m    v1.32.0
# aks-nodepool1-12345678-vmss000002   Ready    agent   5m    v1.32.0
```

### Step 2.5: Install Cluster Essentials

**Install Cert-Manager** (for certificate management):

```bash
# Add Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io
helm repo update

# Install cert-manager
kubectl create namespace cert-manager
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --version v1.17.1 \
  --set installCRDs=true

# Verify installation
kubectl get pods -n cert-manager
```

**Install Metrics Server** (if not already installed):

```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Verify
kubectl get deployment metrics-server -n kube-system
```

---

## Part 3: Storage Configuration

### Step 3.1: Create Azure Storage Account

```bash
# Create storage account
az storage account create \
  --name "$AZURE_STORAGE_ACCOUNT" \
  --resource-group "$AZURE_STORAGE_RESOURCE_GROUP" \
  --location "$AZURE_REGION" \
  --sku Premium_LRS \
  --kind FileStorage \
  --https-only true

# Get storage account key
AZURE_STORAGE_KEY=$(az storage account keys list \
  --account-name "$AZURE_STORAGE_ACCOUNT" \
  --resource-group "$AZURE_STORAGE_RESOURCE_GROUP" \
  --query "[0].value" -o tsv)

echo "Storage Account: $AZURE_STORAGE_ACCOUNT"
echo "Storage Key: $AZURE_STORAGE_KEY"

# Save for later use
export AZURE_STORAGE_KEY
```

### Step 3.2: Deploy Storage Classes

**Add TIBCO Helm Chart Repository**:

```bash
# Add TIBCO helm repo
helm repo add tibco-platform "${TP_TIBCO_HELM_CHART_REPO}"
helm repo update
```

**Deploy Azure Disk and Azure Files Storage Classes using dp-config-aks**:

> [!IMPORTANT]
> Storage classes must be installed in the `storage-system` namespace (not `kube-system`) using the `dp-config-aks` chart with `--labels layer=1` for correct dependency tracking during upgrades and uninstalls.

```bash
helm upgrade --install --wait --timeout 1h --create-namespace \
  -n storage-system dp-config-aks-storage dp-config-aks \
  --labels layer=1 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
httpIngress:
  enabled: false
clusterIssuer:
  create: false
storageClass:
  azuredisk:
    enabled: ${TP_DISK_ENABLED}
    name: ${TP_DISK_STORAGE_CLASS}
    volumeBindingMode: WaitForFirstConsumer
    reclaimPolicy: "Delete"
    # For EMS production environments, consider Retain and explicit Premium disk parameters.
    # reclaimPolicy: "Retain"
    parameters:
      skuName: Premium_LRS
  azurefile:
    enabled: ${TP_FILE_ENABLED}
    name: ${TP_FILE_STORAGE_CLASS}
    volumeBindingMode: WaitForFirstConsumer
    reclaimPolicy: "Delete"
    # For EMS production environments, consider Retain and Premium Azure Files with NFS.
    # reclaimPolicy: "Retain"
    parameters:
      allowBlobPublicAccess: "false"
      # storageAccount: ${TP_STORAGE_ACCOUNT_NAME}
      # resourceGroup: ${TP_STORAGE_ACCOUNT_RESOURCE_GROUP}
      skuName: Premium_LRS
      # protocol: nfs
    # mountOptions:
    #   - soft
    #   - timeo=300
    #   - actimeo=1
    #   - retrans=2
    #   - _netdev
EOF

# Verify
kubectl get storageclass
```

### Step 3.3: Verify Storage Classes

```bash
# List all storage classes
kubectl get storageclass

# Expected output:
# NAME                    PROVISIONER          RECLAIMPOLICY   VOLUMEBINDINGMODE   ALLOWVOLUMEEXPANSION
# azure-disk-sc           disk.csi.azure.com   Delete          WaitForFirstConsumer true
# azure-files-sc          file.csi.azure.com   Delete          WaitForFirstConsumer true
# default (default)       disk.csi.azure.com   Delete          WaitForFirstConsumer true
# managed-csi             disk.csi.azure.com   Delete          WaitForFirstConsumer true
# managed-csi-premium     disk.csi.azure.com   Delete          WaitForFirstConsumer true

# Verify the Helm release is labeled correctly
helm list -n storage-system --selector layer=1
```

---

## Part 4: Ingress Controller Setup

TIBCO Platform supports multiple ingress controllers. Choose **Traefik 3.3.4** (recommended) or **NGINX 4.12.1**.

**Official Method**: Use the `dp-config-aks` Helm chart with proper layer labels for dependency management.

> [!NOTE]
> Helm label `--labels layer=1` is used for dependency tracking. Layer numbers help identify installation order for proper uninstallation sequence.

### Option A: Traefik Ingress Controller (Recommended)

**Step 4.1: Install Traefik using dp-config-aks**

> [!IMPORTANT]
> Install Traefik using the `dp-config-aks` chart into the `ingress-system` namespace with `--labels layer=1`. Do **not** install Traefik directly via its own Helm chart — the `dp-config-aks` wrapper ensures correct AKS integration, layer labeling, and External DNS annotation wiring.

```bash
# Set ingress variables
export TP_INGRESS_CLASS="traefik"

# Install Traefik Ingress Controller with Azure Load Balancer
helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ingress-system dp-config-aks-ingress dp-config-aks \
  --labels layer=1 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
clusterIssuer:
  create: false
httpIngress:
  enabled: false
ingressClass:
  enabled: true
  isDefaultClass: true
traefik:
  enabled: true
  service:
    type: LoadBalancer
    annotations:
      external-dns.alpha.kubernetes.io/hostname: "*.${TP_DOMAIN}"
      service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /healthz
  ingressRoute:
    dashboard:
      enabled: false
  ports:
    web:
      redirectTo:
        port: websecure
    websecure:
      tls:
        enabled: true
  additionalArguments:
    - '--providers.kubernetesingress.ingressendpoint.publishedservice=ingress-system/dp-config-aks-ingress-traefik'
  tlsStore:
    default:
      defaultCertificate:
        secretName: tp-certificate-main-ingress
  providers:
    kubernetesCRD:
      enabled: true
      allowCrossNamespace: true
    kubernetesIngress:
      enabled: true
      allowExternalNameServices: true
  logs:
    general:
      level: INFO
    access:
      enabled: true
  resources:
    requests:
      cpu: "500m"
      memory: "512Mi"
    limits:
      cpu: "2000m"
      memory: "2Gi"
  # Uncomment after DP_NAMESPACE exists if Traefik should send traces to the Data Plane collector.
  # tracing:
  #   otlp:
  #     http:
  #       endpoint: http://otel-userapp-traces.${DP_NAMESPACE}.svc.cluster.local:4318/v1/traces
  #   serviceName: traefik
EOF
```

**Step 4.2: Verify Traefik Deployment**

```bash
# Check Traefik pods
kubectl get pods -n ingress-system

# Check Traefik service and external IP
kubectl get svc -n ingress-system

# Expected output includes LoadBalancer service with EXTERNAL-IP
# NAME                               TYPE           EXTERNAL-IP
# dp-config-aks-ingress-traefik     LoadBalancer   20.x.x.x

# Get ingress class
kubectl get ingressclass
# NAME      CONTROLLER                      PARAMETERS   AGE
# traefik   traefik.io/ingress-controller   <none>       2m
```

### Option B: NGINX Ingress Controller (Alternative) (Deprecated from TP v1.10.0)

> **Warning**: NGINX ingress is deprecated from TIBCO Platform v1.10.0. Use Traefik instead.

```bash
# Add NGINX Helm repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install NGINX
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --version 4.12.1 \
  --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-balancer-health-probe-request-path"=/healthz

# Get Load Balancer IP
export INGRESS_LOAD_BALANCER_IP=$(kubectl get svc nginx-ingress-ingress-nginx-controller -n ingress-nginx -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
```

---

## Part 5: PostgreSQL Database Setup

### Option A: Azure Database for PostgreSQL Flexible Server (Recommended for Production)

**Step 5.1: Create PostgreSQL Flexible Server**

```bash
# Create PostgreSQL Flexible Server
az postgres flexible-server create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "tibco-platform-db" \
  --location "$AZURE_REGION" \
  --admin-user "$POSTGRES_USER" \
  --admin-password "$POSTGRES_PASSWORD" \
  --sku-name Standard_D4s_v3 \
  --tier GeneralPurpose \
  --version 16 \
  --storage-size 128 \
  --backup-retention 7 \
  --high-availability Disabled \
  --public-access 0.0.0.0-255.255.255.255

# Note: For production, restrict public-access to specific IPs or use private link
```

**Step 5.2: Configure Firewall Rules**

```bash
# Allow Azure services
az postgres flexible-server firewall-rule create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "tibco-platform-db" \
  --rule-name "AllowAzureServices" \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 0.0.0.0

# Allow AKS subnet (if using VNet integration)
# az postgres flexible-server firewall-rule create \
#   --resource-group "$AZURE_RESOURCE_GROUP" \
#   --name "tibco-platform-db" \
#   --rule-name "AllowAKSSubnet" \
#   --start-ip-address 10.4.0.0 \
#   --end-ip-address 10.4.15.255
```

**Step 5.3: Create Database and Extensions**

```bash
# Create database
az postgres flexible-server db create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --server-name "tibco-platform-db" \
  --database-name "$POSTGRES_DB"

# Connect to PostgreSQL and create extensions
# Install psql client if not available: brew install postgresql (Mac) or apt-get install postgresql-client (Linux)

# Get fully qualified server name
export POSTGRES_HOST=$(az postgres flexible-server show \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "tibco-platform-db" \
  --query fullyQualifiedDomainName -o tsv)

echo "PostgreSQL Host: $POSTGRES_HOST"

# Connect and create extensions
psql "host=$POSTGRES_HOST port=5432 dbname=$POSTGRES_DB user=$POSTGRES_USER password=$POSTGRES_PASSWORD sslmode=require" <<EOF
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
SELECT * FROM pg_extension;
\q
EOF
```

**Step 5.4: Test Connection from AKS**

```bash
# Create a test pod
kubectl run postgres-test --image=postgres:16 --rm -it --restart=Never -- \
  psql "host=$POSTGRES_HOST port=5432 dbname=$POSTGRES_DB user=$POSTGRES_USER password=$POSTGRES_PASSWORD sslmode=require" \
  -c "SELECT version();"

# Expected output: PostgreSQL 16.x ...
```

### Option B: In-Cluster PostgreSQL using dp-config-aks (Development/Testing Only)

> **Warning**: Not recommended for production. Use Azure managed PostgreSQL instead.

**Official Method**: Use `dp-config-aks` chart to deploy PostgreSQL 16 in the Control Plane namespace.

```bash
# Set PostgreSQL variables
export CP_INSTANCE_ID="cp1"  # Control Plane instance ID (alphanumeric, max 5 chars)
export POSTGRES_PASSWORD="postgres"  # Change for production

# Install PostgreSQL using dp-config-aks
helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ${CP_INSTANCE_ID}-ns postgres-${CP_INSTANCE_ID} dp-config-aks \
  --labels layer=3 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
global:
  tibco:
    containerRegistry:
      url: "csgprduswrepoedge.jfrog.io"
      username: "${TP_CONTAINER_REGISTRY_USER}"
      password: "${TP_CONTAINER_REGISTRY_PASSWORD}"
      repository: "tibco-platform-docker-prod"
  storageClass: ${TP_DISK_STORAGE_CLASS}
postgresql:
  enabled: true
  auth:
    postgresPassword: ${POSTGRES_PASSWORD}
    username: postgres
    password: ${POSTGRES_PASSWORD}
    database: "postgres"
  image:
    registry: "csgprduswrepoedge.jfrog.io"
    repository: tibco-platform-docker-prod/common-postgresql
    tag: 16.4.0-debian-12-r14
    pullSecrets:
    - tibco-container-registry-credentials
  primary:
    resources:
      requests:
        cpu: "250m"
        memory: "512Mi"
      limits:
        cpu: "1"
        memory: "1Gi"
    persistence:
      size: 2Gi
EOF

# Get PostgreSQL connection details
export POSTGRES_HOST="postgres-${CP_INSTANCE_ID}-postgresql.${CP_INSTANCE_ID}-ns.svc.cluster.local"
export POSTGRES_PORT=5432
export POSTGRES_DB="postgres"
export POSTGRES_USER="postgres"

echo "PostgreSQL Host: $POSTGRES_HOST"

# Set host for in-cluster
export POSTGRES_HOST="postgres-${CP_INSTANCE_ID}-postgresql.${CP_INSTANCE_ID}-ns.svc.cluster.local"
```

---

## Part 6: DNS Configuration

DNS is **REQUIRED** for Control Plane and Data Plane communication via secure tunnels.

> [!IMPORTANT]
> For TIBCO Platform 1.15.0+ and current 1.18.0 installations, prefer the simplified DNS model with one Control Plane base domain. For example, use `platform.azure.example.com` as the base domain and create one wildcard record `*.platform.azure.example.com`. Platform Console is then `https://admin.platform.azure.example.com`, subscriptions use `https://<hostPrefix>.platform.azure.example.com`, and hybrid tunnel traffic uses the same wildcard domain with the `/infra/tunnel` route. Keep separate `cp1-my` and `cp1-tunnel` wildcard domains only for legacy environments or explicit separation requirements.

### Step 6.1: Create Azure DNS Zone (if needed)

```bash
# Create DNS zone
az network dns zone create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "platform.azure.example.com"

# List name servers (delegate these in your parent domain)
az network dns zone show \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "platform.azure.example.com" \
  --query nameServers -o table
```

### Step 6.2: Create Wildcard DNS Records

**Option A: Using Azure CLI**

```bash
# Get Load Balancer IP (if not already set)
export INGRESS_LOAD_BALANCER_IP=$(kubectl get svc dp-config-aks-ingress-traefik -n ingress-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Create one wildcard A record for the simplified Control Plane base domain
az network dns record-set a add-record \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --zone-name "platform.azure.example.com" \
  --record-set-name "*" \
  --ipv4-address "$INGRESS_LOAD_BALANCER_IP"

# Legacy split-DNS option only: create separate *.cp1-my and *.cp1-tunnel records
# if your environment intentionally keeps application and tunnel domains separate.

# Create wildcard A record for Data Plane domain (for BWCE/Flogo apps)
az network dns record-set a add-record \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --zone-name "platform.azure.example.com" \
  --record-set-name "*.dp1" \
  --ipv4-address "$INGRESS_LOAD_BALANCER_IP"

# Verify DNS records
az network dns record-set a list \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --zone-name "platform.azure.example.com" \
  --query "[].{Name:name, IP:aRecords[0].ipv4Address}" -o table
```

**Option B: Using External DNS (Recommended for Production)**

See [how-to-add-dns-records-aks-azure](how-to-add-dns-records-aks-azure) for detailed External DNS setup.

### Step 6.3: Verify DNS Resolution

```bash
# Test DNS resolution (wait 1-2 minutes for propagation)
nslookup admin.platform.azure.example.com
nslookup account.platform.azure.example.com
nslookup myapp.dp1.platform.azure.example.com

# All should resolve to: $INGRESS_LOAD_BALANCER_IP
```

---

## Part 7: Certificate Management

### Option A: Self-Signed Certificates (Development/Testing)

**Step 7.1: Generate Certificates**

```bash
# Use the provided certificate generation script
cd /path/to/workshop-tp-aks

# Source environment variables (if not already done)
source scripts/aks-env-variables.sh

# Generate certificates
./scripts/generate-certificates.sh

# Certificates will be created in ./certs/ directory
ls -la certs/
```

**Step 7.2: Create Kubernetes TLS Secrets**

```bash
# Create Control Plane namespace
kubectl create namespace $TP_CP_NAMESPACE

# Create TLS secret for MY domain
kubectl create secret tls cp-my-tls-cert \
  --cert=certs/cp-my-cert.crt \
  --key=certs/cp-my-key.pem \
  --namespace $TP_CP_NAMESPACE

# Legacy split-DNS option only: create a separate TUNNEL TLS secret when
# CP_MY_DNS_DOMAIN and CP_TUNNEL_DNS_DOMAIN use different base domains.
# kubectl create secret tls cp-tunnel-tls-cert \
#   --cert=certs/cp-tunnel-cert.crt \
#   --key=certs/cp-tunnel-key.pem \
#   --namespace $TP_CP_NAMESPACE

# Verify secrets
kubectl get secrets -n $TP_CP_NAMESPACE | grep tls
```

### Option B: Let's Encrypt Certificates (Production)

**Step 7.1: Create ClusterIssuer for Let's Encrypt**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: traefik
EOF

# Verify ClusterIssuer
kubectl get clusterissuer letsencrypt-prod
```

**Step 7.2: Certificate Annotations**

When using Let's Encrypt, add these annotations to your ingress resources:

```yaml
annotations:
  cert-manager.io/cluster-issuer: "letsencrypt-prod"
```

Certificates will be automatically provisioned when ingress resources are created.

---

## Part 8: Control Plane Deployment

### Step 8.1: Pre-requisites - Create Namespace and Service Account

**First**, create the Control Plane namespace with proper labels:

```bash
# Set Control Plane Instance ID
export CP_INSTANCE_ID="cp1"  # Unique ID (alphanumeric, max 5 chars)

# Create namespace with labels
kubectl apply -f <(envsubst '${CP_INSTANCE_ID}' <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: ${CP_INSTANCE_ID}-ns
  labels:
    platform.tibco.com/controlplane-instance-id: ${CP_INSTANCE_ID}
EOF
)

# Create service account for Control Plane
kubectl create serviceaccount ${CP_INSTANCE_ID}-sa -n ${CP_INSTANCE_ID}-ns
```

### Step 8.2: Configure DNS Records and Certificates

**Step 8.2.1: Label ingress-system namespace** (required for network policies)

```bash
kubectl label namespace ingress-system networking.platform.tibco.com/non-cp-ns=enable --overwrite=true
```

**Step 8.2.2: Create Certificate using cert-manager**

```bash
# Set domain variables
export TP_BASE_DNS_DOMAIN="${TP_BASE_DNS_DOMAIN:-${TP_MAIN_INGRESS_SANDBOX_SUBDOMAIN}.${TP_SANDBOX}.${TP_TOP_LEVEL_DOMAIN}}"
export CP_MY_DNS_DOMAIN="${TP_BASE_DNS_DOMAIN}"
export CP_TUNNEL_DNS_DOMAIN="${TP_BASE_DNS_DOMAIN}"

# Legacy split-DNS option:
# export CP_MY_DNS_DOMAIN="${CP_INSTANCE_ID}-my.${TP_BASE_DNS_DOMAIN}"
# export CP_TUNNEL_DNS_DOMAIN="${CP_INSTANCE_ID}-tunnel.${TP_BASE_DNS_DOMAIN}"

# Create certificate in CP namespace
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: tp-certificate-${CP_INSTANCE_ID}
  namespace: ${CP_INSTANCE_ID}-ns
spec:
  dnsNames:
  - '*.${CP_MY_DNS_DOMAIN}'
  # Legacy split-DNS option only:
  # - '*.${CP_TUNNEL_DNS_DOMAIN}'
  issuerRef:
    kind: ClusterIssuer
    name: cic-cert-subscription-scope-production-main
  secretName: tp-certificate-${CP_INSTANCE_ID}
EOF

# Wait for certificate to be ready
kubectl wait --for=condition=Ready certificate/tp-certificate-${CP_INSTANCE_ID} -n ${CP_INSTANCE_ID}-ns --timeout=300s

# Verify certificate
kubectl get certificate -n ${CP_INSTANCE_ID}-ns
kubectl describe certificate tp-certificate-${CP_INSTANCE_ID} -n ${CP_INSTANCE_ID}-ns
```

> **Note**: If you haven't set up cert-manager ClusterIssuer yet, refer to [AKS cluster-setup documentation](https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/docs/workshop/aks/cluster-setup#install-cluster-issuer).

### Step 8.3: Create Required Kubernetes Secrets

**1. Session Keys Secret (REQUIRED)**

This secret is mandatory for router pods to start correctly.

```bash
# Generate session keys
export TSC_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)
export DOMAIN_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)

# Create Kubernetes secret
kubectl create secret generic session-keys -n ${CP_INSTANCE_ID}-ns \
  --from-literal=TSC_SESSION_KEY=${TSC_SESSION_KEY} \
  --from-literal=DOMAIN_SESSION_KEY=${DOMAIN_SESSION_KEY}

# Verify
kubectl get secret session-keys -n ${CP_INSTANCE_ID}-ns
```

**2. CP Orchestration Encryption Secret (REQUIRED)**

```bash
# Generate encryption secret
export CP_ENCRYPTION_SECRET=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c44)

# Create secret in Control Plane namespace
kubectl create secret -n ${CP_INSTANCE_ID}-ns generic cporch-encryption-secret \
  --from-literal=CP_ENCRYPTION_SECRET=${CP_ENCRYPTION_SECRET}

# Verify
kubectl get secret cporch-encryption-secret -n ${CP_INSTANCE_ID}-ns
```

**3. Container Registry Secret (REQUIRED)**

```bash
# Set TIBCO container registry credentials
export TP_CONTAINER_REGISTRY_URL="csgprduswrepoedge.jfrog.io"
export TP_CONTAINER_REGISTRY_USER="<your-jfrog-username>"
export TP_CONTAINER_REGISTRY_PASSWORD="<your-jfrog-password>"
export TP_CONTAINER_REGISTRY_REPOSITORY="tibco-platform-docker-prod"

kubectl create secret docker-registry tibco-container-registry-credentials \
  --namespace ${CP_INSTANCE_ID}-ns \
  --docker-server=${TP_CONTAINER_REGISTRY_URL} \
  --docker-username=${TP_CONTAINER_REGISTRY_USER} \
  --docker-password=${TP_CONTAINER_REGISTRY_PASSWORD}

# Verify
kubectl get secret tibco-container-registry-credentials -n ${CP_INSTANCE_ID}-ns
```

**4. PostgreSQL Database Credentials Secret (optional for Azure PostgreSQL)**

The `tibco-cp-base` chart can create `provider-cp-database-credentials` from `db_username` and `db_password` in values. For customer environments, you can instead pre-create the secret and keep credentials out of checked-in values files.

```bash
kubectl create secret generic provider-cp-database-credentials \
  --from-literal=USERNAME="$POSTGRES_USER" \
  --from-literal=PASSWORD="$POSTGRES_PASSWORD" \
  --namespace ${CP_INSTANCE_ID}-ns
```

**5. PostgreSQL SSL Root Certificate Secret (recommended for Azure PostgreSQL)**

Azure Database for PostgreSQL Flexible Server requires encrypted connections in most customer environments. When `db_ssl_mode` is not `disable`, `tibco-cp-base` expects a Kubernetes secret containing the trusted PostgreSQL CA bundle.

```bash
# Download or provide the CA bundle required by your Azure PostgreSQL server.
# Keep the secret key name aligned with global.tibco.db_ssl_root_cert_filename.
export POSTGRES_SSL_ROOT_CERT_FILE="/path/to/azure-postgres-ca.pem"

kubectl create secret generic db-ssl-root-cert \
  --from-file=db_ssl_root.cert="${POSTGRES_SSL_ROOT_CERT_FILE}" \
  --namespace ${CP_INSTANCE_ID}-ns

kubectl get secret db-ssl-root-cert -n ${CP_INSTANCE_ID}-ns
```

> **Note**: If using in-cluster PostgreSQL from `dp-config-aks`, the PostgreSQL password secret is created by that chart. The Azure PostgreSQL SSL root certificate secret is separate and must be created when `db_ssl_mode` is not `disable`.

### Step 8.4: Export Additional Variables Required for Chart Values

```bash
# Network and ingress variables
export TP_VNET_CIDR="10.4.0.0/16"
export TP_SERVICE_CIDR="10.0.0.0/16"
export TP_INGRESS_CLASS="traefik"  # or "nginx"
export TP_ENABLE_NETWORK_POLICY="false"  # Set to "true" for production

# PostgreSQL connection (for in-cluster PostgreSQL)
export POSTGRES_HOST="postgres-${CP_INSTANCE_ID}-postgresql.${CP_INSTANCE_ID}-ns.svc.cluster.local"
export POSTGRES_PORT=5432

# Or for Azure PostgreSQL Flexible Server
# export POSTGRES_HOST="tibco-platform-db.postgres.database.azure.com"
# export POSTGRES_PORT=5432
# export POSTGRES_SSL_MODE="require"
# export POSTGRES_SSL_ROOT_CERT_SECRET="db-ssl-root-cert"
# export POSTGRES_SSL_ROOT_CERT_FILENAME="db_ssl_root.cert"
```

### Step 8.5: Configure Control Plane Helm Values

Create the official Control Plane values file using the **tibco-cp-base** chart structure:

> [!IMPORTANT]
> **Critical Database Configuration**: The values file below includes **all required configuration sections** including:
> - **Database connection details** (`db_host`, `db_name`, `db_port`, `db_username`, `db_password`, `db_secret_name`, `db_ssl_mode`)
> - **Admin user configuration** (for initial platform administrator)
> - **Encryption secret configuration** (for platform security)
> 
> If any of these sections are missing (especially the database configuration), the Control Plane deployment will fail with errors like "missing DBHost key in ConfigMap provider-cp-database-config".
>
> For 1.18.0, email server configuration is no longer supplied through Control Plane Helm values. Configure email in Platform Console after deployment if activation emails, notifications, or reports are required.

```bash
cat > cp-values.yaml <<EOF
# TIBCO Platform Control Plane Values for AKS
# Based on: https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/docs/workshop/aks/control-plane

tp-cp-core-finops:
  finops:
    enabled: true

tp-cp-integration-bwprovisioner:
  bwprovisioner:
    enabled: true

tp-cp-integration-bw5provisioner:
  bw5provisioner:
    enabled: true

tp-cp-integration-flogoprovisioner:
  flogoprovisioner:
    enabled: true

hybrid-proxy:
  ingress:
    enabled: true
    ingressClassName: "${TP_INGRESS_CLASS}"
    tls:
      - secretName: tp-certificate-${CP_INSTANCE_ID}
        hosts:
          - '*.${CP_TUNNEL_DNS_DOMAIN}'
    hosts:
      - host: '*.${CP_TUNNEL_DNS_DOMAIN}'
        paths:
          - path: /
            pathType: Prefix
            port: 105

tp-cp-bootstrap-cronjobs:
  cronjobs:
    setupJob:
      enable: true

router-operator:
  enabled: true
  # SecretNames for environment variables TSC_SESSION_KEY and DOMAIN_SESSION_KEY
  tscSessionKey:
    secretName: session-keys  # default secret name
    key: TSC_SESSION_KEY
  domainSessionKey:
    secretName: session-keys  # default secret name
    key: DOMAIN_SESSION_KEY
  ingress:
    enabled: true
    ingressClassName: "${TP_INGRESS_CLASS}"
    tls:
      - secretName: tp-certificate-${CP_INSTANCE_ID}
        hosts:
          - '*.${CP_MY_DNS_DOMAIN}'
    hosts:
      - host: '*.${CP_MY_DNS_DOMAIN}'
        paths:
          - path: /
            pathType: Prefix
            port: 100

global:
  tibco:
    createNetworkPolicy: ${TP_ENABLE_NETWORK_POLICY}
    
    # Container Registry
    containerRegistry:
      url: "${TP_CONTAINER_REGISTRY_URL}"
      username: "${TP_CONTAINER_REGISTRY_USER}"
      password: "${TP_CONTAINER_REGISTRY_PASSWORD}"
      repository: "${TP_CONTAINER_REGISTRY_REPOSITORY}"
    db_ssl_root_cert_secretname: "${POSTGRES_SSL_ROOT_CERT_SECRET:-db-ssl-root-cert}"
    db_ssl_root_cert_filename: "${POSTGRES_SSL_ROOT_CERT_FILENAME:-db_ssl_root.cert}"
    
    # Control Plane Instance
    controlPlaneInstanceId: "${CP_INSTANCE_ID}"
    serviceAccount: "${CP_INSTANCE_ID}-sa"
  
  external:
    clusterInfo:
      nodeCIDR: "${TP_VNET_CIDR}"
      podCIDR: "${TP_POD_CIDR}"  # Optional: Kubernetes Pod CIDR
      serviceCIDR: "${TP_SERVICE_CIDR}"  # Optional: Kubernetes Service CIDR
    
    # DNS Domains
    dnsDomain: "${CP_MY_DNS_DOMAIN}"
    dnsTunnelDomain: "${CP_TUNNEL_DNS_DOMAIN}"
    
    # Storage Configuration
    storage:
      pvcName: "control-plane-pvc"
      resources:
        requests:
          storage: "10Gi"
      storageClassName: "${TP_FILE_STORAGE_CLASS}"
    
    # Database Configuration
    db_host: "${POSTGRES_HOST}"
    db_name: "${POSTGRES_DB:-postgres}"
    db_port: ${POSTGRES_PORT}
    db_username: "${POSTGRES_USER:-postgres}"
    db_password: "${POSTGRES_PASSWORD}"
    db_secret_name: "provider-cp-database-credentials"
    db_ssl_mode: "${POSTGRES_SSL_MODE:-require}"  # Use "disable" only for dev/test in-cluster PostgreSQL
    db_ssl_root_cert: "/private/tsc/certificates/${POSTGRES_SSL_ROOT_CERT_FILENAME:-db_ssl_root.cert}"
    
    # Admin User Configuration
    admin:
      email: "admin@example.com"  # Replace with actual admin email
      firstname: "Platform"
      lastname: "Admin"
      customerID: "customer-id"  # Replace with actual customer ID
    
    # Encryption Secret Configuration
    cpEncryptionSecretName: "cporch-encryption-secret"
    cpEncryptionSecretKey: "CP_ENCRYPTION_SECRET"
    
    # Optional: Audit Server Configuration
    # auditserver:
    #   index: "audittrail"
    #   endpoint: ""
    #   username: ""
    #   password: ""
    
    # Environment
    environment: "production"
EOF
```

> [!NOTE]
> If you are upgrading older 1.17.x values files, remove these deprecated 1.18.0 fields before deploying: `global.external.emailServerType`, `global.external.emailServer`, `global.external.fromAndReplyToEmailAddress`, `global.external.cronJobReportsEmailAlias`, and `global.external.platformEmailNotificationCcAddresses`. The official `tp-helm-charts/scripts/1.18.0/upgrade.sh` assistant performs this cleanup automatically during values generation.

> [!TIP]
> **Verify Database Configuration After Deployment**: After the chart is installed, verify that the database configuration was correctly applied:
> ```bash
> # Check if the ConfigMap contains the DBHost key
> kubectl get configmap provider-cp-database-config -n ${CP_INSTANCE_ID}-ns -o yaml | grep -i "host"
> 
> # Expected output should show:
> #   DBHost: postgres-cp1-postgresql.cp1-ns.svc.cluster.local  (or your DB host)
> ```
> 
> If the DBHost is missing from the ConfigMap, it indicates the database configuration was not included in the Helm values, and you'll need to redeploy with the corrected configuration.

---

### Alternative: Gateway API Configuration (tibco-cp-base with HTTPRoutes)

> [!NOTE]
> **When to use this:** Choose the Gateway API path if you have NGINX Gateway Fabric (or another Gateway API controller) installed and want `HTTPRoute` resources instead of classic `Ingress` objects for hybrid-proxy and router-operator. The rest of the `cp-values.yaml` (database, admin user, storage, etc.) remains unchanged — create a second override file and pass both files to `helm upgrade`.

Set the gateway env vars (already added to `aks-env-variables.sh`):

```bash
echo "TP_GATEWAY_NAME=${TP_GATEWAY_NAME}"           # e.g. tp-ngf-gateway
echo "TP_GATEWAY_NAMESPACE=${TP_GATEWAY_NAMESPACE}" # e.g. ingress-system
echo "TP_GATEWAY_CLASS=${TP_GATEWAY_CLASS}"         # e.g. nginx
```

Create the Gateway API override file:

```bash
cat > cp-gateway-api-values.yaml <<EOF
hybrid-proxy:
  enabled: true
  gatewayRoute:
    enabled: true
    controllerName: ${TP_GATEWAY_CLASS}
    hostnames:
    - '${CP_INSTANCE_ID}-tunnel.${TP_BASE_DNS_DOMAIN}'  # Dedicated tunnel back-channel
    parentRefs:
    - name: ${TP_GATEWAY_NAME}
      namespace: ${TP_GATEWAY_NAMESPACE}
    annotations:
      external-dns.alpha.kubernetes.io/hostname: '*.${TP_BASE_DNS_DOMAIN}'

otel-collector:
  enabled: true

router-operator:
  gatewayRoute:
    enabled: true
    controllerName: ${TP_GATEWAY_CLASS}
    hostnames:
    - '*.${TP_BASE_DNS_DOMAIN}'  # Wildcard captures all current and future subscriptions
    parentRefs:
    - name: ${TP_GATEWAY_NAME}
      namespace: ${TP_GATEWAY_NAMESPACE}
    annotations:
      external-dns.alpha.kubernetes.io/hostname: '*.${TP_BASE_DNS_DOMAIN}'
EOF
```

Install `tibco-cp-base` with both files (the base values plus the Gateway API override):

```bash
helm upgrade --install --wait --timeout 30m \
  -n ${CP_INSTANCE_ID}-ns platform-base tibco-cp-base \
  --labels layer=5 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" \
  --version "${TP_CP_BASE_CHART_VERSION}" \
  --values cp-values.yaml \
  --values cp-gateway-api-values.yaml
```

Verify the generated HTTPRoutes:

```bash
kubectl get httproute -n ${CP_INSTANCE_ID}-ns
kubectl describe httproute -n ${CP_INSTANCE_ID}-ns
```

> [!TIP]
> The `*.${TP_BASE_DNS_DOMAIN}` wildcard hostname on `router-operator` captures admin, subscription, and any future portal hostnames without requiring individual entries. The `hybrid-proxy` uses an explicit `${CP_INSTANCE_ID}-tunnel.${TP_BASE_DNS_DOMAIN}` hostname so the tunnel back-channel stays isolated from the wildcard.

---

### Step 8.6: Deploy Control Plane

```bash
# Add TIBCO Helm repository
helm repo add tibco-platform ${TP_TIBCO_HELM_CHART_REPO}
helm repo update

# Set chart version for the current release
export TP_CP_BASE_CHART_VERSION="${TP_CP_BASE_CHART_VERSION:-1.18.0}"

# Install TIBCO Platform Control Plane
helm upgrade --install --wait --timeout 30m \
  -n ${CP_INSTANCE_ID}-ns platform-base tibco-cp-base \
  --labels layer=5 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" \
  --version "${TP_CP_BASE_CHART_VERSION}" \
  --values cp-values.yaml

# Monitor deployment
kubectl get pods -n ${CP_INSTANCE_ID}-ns --watch
```

**Expected deployment time**: 10-20 minutes

### Step 8.7: Verify Control Plane Deployment

```bash
# Check all pods are running (may take 10-15 minutes)
kubectl get pods -n ${CP_INSTANCE_ID}-ns

# All pods should show STATUS: Running or Completed
# Example:
# NAME                                          READY   STATUS    RESTARTS
# cp-proxy-xxxxxxxxx-xxxxx                      1/1     Running   0
# idm-xxxxxxxxx-xxxxx                           1/1     Running   0
# ...

# Check ingress resources
kubectl get ingress -n ${CP_INSTANCE_ID}-ns

# Check services
kubectl get svc -n ${CP_INSTANCE_ID}-ns

# Check PVCs (if any)
kubectl get pvc -n ${CP_INSTANCE_ID}-ns

# View Control Plane proxy logs
kubectl logs -n ${CP_INSTANCE_ID}-ns -l app.kubernetes.io/component=cp-proxy -f
```

### Step 8.7.1: Install Capability Charts (Required for BWCE, Flogo, and EMS)

> [!IMPORTANT]
> **Critical Step for TIBCO Platform 1.12.0+**: Starting from version 1.12.0, the TIBCO Platform architecture has changed. The capability charts are **decoupled** from the base infrastructure chart (`tibco-cp-base`). You **must** install them separately in your Control Plane namespace to enable provisioning functionality for BWCE, Flogo, and EMS (Messaging).
> 
> **What this resolves**: If you attempt to provision BWCE, Flogo, or EMS capabilities without installing these charts, you will encounter the error: **"required charts for this capability not deployed"**.

**Why this step is needed:** The capability charts provide:
- **BWCE & BW5**: Runtime recipes, templates, and configurations for BusinessWorks Container Edition
- **Flogo**: Runtime recipes, templates, and configurations for Flogo applications  
- **EMS (Messaging)**: Runtime recipes, templates, and configurations for Enterprise Messaging Service

**Installation Instructions:**

You can reuse the `cp-values.yaml` file you used for the Control Plane installation, or extract the values from your deployed release.

**Option 1: Using existing values file**
```bash
# Set the chart version to match your tibco-cp-base version
export CP_CAPABILITY_CHART_VERSION="${TP_CP_BASE_CHART_VERSION:-1.18.0}"  # Should match your CP version

# Install BWCE & BW5 capability chart
helm upgrade --install --wait --timeout 15m \
  -n ${CP_INSTANCE_ID}-ns tibco-cp-bw tibco-cp-bw \
  --labels layer=5 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" \
  --version "${CP_CAPABILITY_CHART_VERSION}" \
  --values cp-values.yaml

# Install Flogo capability chart
helm upgrade --install --wait --timeout 15m \
  -n ${CP_INSTANCE_ID}-ns tibco-cp-flogo tibco-cp-flogo \
  --labels layer=5 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" \
  --version "${CP_CAPABILITY_CHART_VERSION}" \
  --values cp-values.yaml

# Install EMS (Messaging) capability chart
helm upgrade --install --wait --timeout 15m \
  -n ${CP_INSTANCE_ID}-ns tibco-cp-messaging tibco-cp-messaging \
  --labels layer=5 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" \
  --version "${CP_CAPABILITY_CHART_VERSION}" \
  --values cp-values.yaml
```

**Option 2: Extract values from deployed Control Plane release**
```bash
# Extract values from the deployed Control Plane release
helm get values platform-base -n ${CP_INSTANCE_ID}-ns -o yaml > capability-charts-values.yaml

# Install capability charts using extracted values
helm upgrade --install --wait --timeout 15m \
  -n ${CP_INSTANCE_ID}-ns tibco-cp-bw tibco-cp-bw \
  --labels layer=5 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" \
  --version "${CP_CAPABILITY_CHART_VERSION}" \
  -f capability-charts-values.yaml

helm upgrade --install --wait --timeout 15m \
  -n ${CP_INSTANCE_ID}-ns tibco-cp-flogo tibco-cp-flogo \
  --labels layer=5 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" \
  --version "${CP_CAPABILITY_CHART_VERSION}" \
  -f capability-charts-values.yaml

helm upgrade --install --wait --timeout 15m \
  -n ${CP_INSTANCE_ID}-ns tibco-cp-messaging tibco-cp-messaging \
  --labels layer=5 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" \
  --version "${CP_CAPABILITY_CHART_VERSION}" \
  -f capability-charts-values.yaml
```

**Verify capability chart installations:**
```bash
# Check all Helm releases in the Control Plane namespace
helm list -n ${CP_INSTANCE_ID}-ns

# You should see at least these releases:
# - platform-base (tibco-cp-base)
# - tibco-cp-bw
# - tibco-cp-flogo
# - tibco-cp-messaging

# Verify pods are running
kubectl get pods -n ${CP_INSTANCE_ID}-ns | grep -E 'bw|flogo|messaging'
```

> [!NOTE]
> **Chart Version Compatibility**: The capability charts should use the **same version** as your Control Plane installation. Ensure `CP_CAPABILITY_CHART_VERSION` matches your deployed Control Plane version.
>
> **Installation Time**: Each capability chart typically takes 5-10 minutes to install. The `--wait` flag ensures Helm waits for all resources to be ready before completing.

> [!TIP]
> **Selective Installation**: If you only need specific capabilities, install only the required capability charts. For 1.18.0, the published artifact list includes `tibco-cp-bw:1.18.0` and `tibco-cp-flogo:1.18.0`; install Messaging/Hawk/Developer Hub charts only when those capabilities are part of your licensed release and available in the chart repository for that version.

**Common Issues and Troubleshooting:**

If capability chart installation fails:

```bash
# Check the status of the Helm release
helm status tibco-cp-bw -n ${CP_INSTANCE_ID}-ns

# View detailed logs of failed pods
kubectl describe pod <pod-name> -n ${CP_INSTANCE_ID}-ns

# Check for resource constraints
kubectl top nodes
kubectl top pods -n ${CP_INSTANCE_ID}-ns

# Uninstall and retry if needed
helm uninstall tibco-cp-bw -n ${CP_INSTANCE_ID}-ns
# Then re-run the install command
```

**Reference Documentation:**
- [TIBCO Control Plane 1.18.0 User Guide - Capability Charts](https://docs.tibco.com/pub/platform-cp/1.18.0/doc/html/Default.htm#Installation/deploying-control-plane-in-kubernetes.htm)
- [tibco-cp-bw Chart README](https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/charts/tibco-cp-bw)
- [tibco-cp-flogo Chart README](https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/charts/tibco-cp-flogo)

---

### Step 8.8: Access Control Plane UI

```bash
# Control Plane Admin Portal URL (adminHostPrefix defaults to "admin")
export CP_ADMIN_URL="https://admin.${CP_MY_DNS_DOMAIN}"

echo "==============================================="
echo "TIBCO Platform Control Plane Admin Portal:"
echo "$CP_ADMIN_URL"
echo "==============================================="
echo "Username: admin"
echo "Password: (configured during initial setup)"
echo ""
echo "After login, create a subscription to get:"
echo "  Subscription Portal: https://<hostPrefix>.${CP_MY_DNS_DOMAIN}"
echo "==============================================="
```

Open your browser and navigate to the Control Plane URL.

**Initial Login**: On first access, you'll be prompted to:
1. Accept the license agreement
2. Set admin password
3. Configure email server in Platform Console for 1.18.0+ if notifications are required
4. Upload TIBCO Platform license

### Step 8.9: Configure Email Server in Platform Console (1.18.0+)

For TIBCO Platform Control Plane 1.18.0 and later, configure email after deployment from Platform Console instead of adding SMTP, SES, or SendGrid settings to `cp-values.yaml`.

Use Platform Console to configure the mail provider before enabling workflows that depend on email, such as user activation, alerts, reports, and notifications. Older Helm values fields under `global.external.emailServer*` are deprecated for 1.18.0 and should not be reintroduced during install or upgrade.

---

## Part 9: Data Plane Deployment

> [!NOTE]
> Data Plane deployment on the same cluster as Control Plane follows official TIBCO procedures. The Data Plane will communicate with the Control Plane via DNS and secure tunnels, not requiring VNet peering.

### Step 9.1: Pre-requisites - Namespace and Service Account

**Create Data Plane Namespace with Required Labels**

```bash
# Export DP variables (if not already set)
export DP_INSTANCE_ID="dp1"
export DP_NAMESPACE="ns"  # Primary namespace name for Data Plane

# Create namespace with required labels
kubectl create namespace ${DP_NAMESPACE}
kubectl label namespace ${DP_NAMESPACE} \
  platform.tibco.com/dataplane-id=${DP_INSTANCE_ID} \
  platform.tibco.com/workload-type=infra \
  networking.platform.tibco.com/non-cp-ns=enable

# Create service account for Data Plane
kubectl create serviceaccount ${DP_INSTANCE_ID}-sa -n ${DP_NAMESPACE}
```

**Verify namespace and service account creation**:
```bash
kubectl get namespace ${DP_NAMESPACE} --show-labels
kubectl get sa ${DP_INSTANCE_ID}-sa -n ${DP_NAMESPACE}
```

### Step 9.2: Install Observability Stack (Optional but Recommended)

Before deploying the Data Plane, install the observability stack for monitoring and logging.

**Install Elastic ECK Operator**

```bash
# Install eck-operator
helm upgrade --install --wait --timeout 1h --labels layer=1 \
  --create-namespace -n elastic-system eck-operator eck-operator \
  --repo "https://helm.elastic.co" --version "2.16.0"

# Verify operator installation
kubectl logs -n elastic-system sts/elastic-operator
```

**Deploy Elastic Stack (Elasticsearch, Kibana, APM)**

```bash
export TP_ES_RELEASE_NAME="dp-config-es"  # Elastic stack release name

helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n elastic-system ${TP_ES_RELEASE_NAME} dp-config-es \
  --labels layer=2 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
domain: ${TP_DOMAIN}
es:
  version: "8.17.3"
  ingress:
    ingressClassName: ${TP_INGRESS_CLASS}
    service: ${TP_ES_RELEASE_NAME}-es-http
  storage:
    name: ${TP_DISK_STORAGE_CLASS}
kibana:
  version: "8.17.3"
  ingress:
    ingressClassName: ${TP_INGRESS_CLASS}
    service: ${TP_ES_RELEASE_NAME}-kb-http
apm:
  enabled: true
  version: "8.17.3"
  ingress:
    ingressClassName: ${TP_INGRESS_CLASS}
    service: ${TP_ES_RELEASE_NAME}-apm-http
EOF
```

**Verify Elastic Stack Installation**

```bash
# Check index templates
kubectl get -n elastic-system IndexTemplates

# Expected output:
# dp-config-es-jaeger-service-index-template
# dp-config-es-jaeger-span-index-template
# dp-config-es-user-apps-index-template

# Check indices
kubectl get -n elastic-system Indices

# Get Kibana URL
kubectl get ingress -n elastic-system dp-config-es-kibana -o jsonpath='{.spec.rules[0].host}'

# Get Elasticsearch password
kubectl get secret dp-config-es-es-elastic-user -n elastic-system -o jsonpath="{.data.elastic}" | base64 --decode; echo
```

**Install Prometheus and Grafana**

```bash
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n prometheus-system kube-prometheus-stack kube-prometheus-stack \
  --labels layer=2 \
  --repo "https://prometheus-community.github.io/helm-charts" --version "48.3.4" -f - <<EOF
grafana:
  plugins:
    - grafana-piechart-panel
  ingress:
    enabled: true
    ingressClassName: ${TP_INGRESS_CLASS}
    hosts:
    - grafana.${TP_DOMAIN}
prometheus:
  prometheusSpec:
    enableRemoteWriteReceiver: true
    externalLabels:
      cluster: ${TP_CLUSTER_NAME}
    remoteWrite:
    - url: http://otel-userapp-metrics.${DP_NAMESPACE}.svc.cluster.local:8889/api/v1/write
EOF
```

**Verify Prometheus Installation**

```bash
# Get Grafana URL
kubectl get ingress -n prometheus-system kube-prometheus-stack-grafana -o jsonpath='{.spec.rules[0].host}'

# Default Grafana credentials: admin / prom-operator
```

### Step 9.3: Deploy Data Plane - Configure Namespace

The `dp-configure-namespace` chart sets up the Data Plane namespace with network policies, service accounts, and observability configurations.

```bash
export TP_DNS_DOMAIN="${TP_DOMAIN}"  # Main DNS domain for DP
export TP_SANDBOX="${DP_INSTANCE_ID}"  # Sandbox subdomain
export TP_INGRESS_CLASS="nginx"  # or "traefik"
export TP_SERVICE_CIDR="10.0.0.0/16"  # AKS service CIDR
export TP_POD_CIDR="10.244.0.0/16"  # AKS pod CIDR (adjust based on your cluster)
export TP_DP_CONFIGURE_NAMESPACE_CHART_VERSION="${TP_DP_CONFIGURE_NAMESPACE_CHART_VERSION:-1.18.3}"

helm upgrade --install --wait --timeout 1h \
  -n ${DP_NAMESPACE} dp-configure-namespace dp-configure-namespace \
  --labels layer=3 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "${TP_DP_CONFIGURE_NAMESPACE_CHART_VERSION}" -f - <<EOF
global:
  tibco:
    dataPlaneId: "${DP_INSTANCE_ID}"
    subscriptionId: "sub1"  # Subscription identifier
    serviceAccount: "${DP_INSTANCE_ID}-sa"
    primaryNamespaceName: "${DP_NAMESPACE}"
    containerRegistry:
      url: "${TP_CONTAINER_REGISTRY_URL}"
      username: "${TP_CONTAINER_REGISTRY_USER}"
      password: "${TP_CONTAINER_REGISTRY_PASSWORD}"
      repository: "${TP_CONTAINER_REGISTRY_REPOSITORY}"

dns:
  domain: "${TP_DNS_DOMAIN}"

# Observability configuration
otel:
  services:
    traces:
      grpc:
        enabled: true
      http:
        enabled: true
    metrics:
      grpc:
        enabled: true
      http:
        enabled: true

# Elastic observability backend
eso:
  enabled: true
  elasticsearch:
    endpoint: "https://dp-config-es-es-http.elastic-system.svc.cluster.local:9200"
    protocol: "https"
    secretName: "dp-config-es-es-elastic-user"

# Prometheus observability backend
prom:
  enabled: true
  remoteWriteEndpoint: "http://kube-prometheus-stack-prometheus.prometheus-system.svc.cluster.local:9090/api/v1/write"
  queryEndpoint: "http://kube-prometheus-stack-prometheus.prometheus-system.svc.cluster.local:9090"

# Network configuration
ingress:
  ingressClassName: "${TP_INGRESS_CLASS}"
  fqdn:
    kind: "shared"

networkPolicy:
  create: ${TP_ENABLE_NETWORK_POLICY}
  ingress:
    podCidr: "${TP_POD_CIDR}"
    serviceCidr: "${TP_SERVICE_CIDR}"
EOF
```

**Verify dp-configure-namespace deployment**

```bash
# Check all resources
kubectl get all -n ${DP_NAMESPACE}

# Check OTEL collectors
kubectl get pods -n ${DP_NAMESPACE} -l app.kubernetes.io/name=opentelemetry-collector

# Check service monitors (if Prometheus is installed)
kubectl get servicemonitor -n ${DP_NAMESPACE}
```

### Step 9.4: Deploy Data Plane - Core Infrastructure

The `dp-core-infrastructure` chart deploys the core Data Plane components including tibtunnel and provisioner agent.

**Get Data Plane Registration Information from Control Plane UI**:

1. Login to Control Plane UI: `https://admin.${CP_MY_DNS_DOMAIN}`
2. Navigate to **Settings** → **Clusters**
3. Click **Add Cluster**
4. Select **AKS** as cluster type
5. Copy the following values:
   - **Data Plane ID**: Should match `${DP_INSTANCE_ID}`
   - **Subscription ID**: Your subscription identifier
   - **Access Key**: Required for tibtunnel configuration

```bash
# Set the access key from Control Plane UI
export TP_DP_ACCESS_KEY="your-access-key-from-cp-ui"
export TP_DP_CORE_INFRA_CHART_VERSION="${TP_DP_CORE_INFRA_CHART_VERSION:-1.18.4}"

# Deploy dp-core-infrastructure
helm upgrade --install --wait --timeout 1h \
  -n ${DP_NAMESPACE} dp-core-infrastructure dp-core-infrastructure \
  --labels layer=4 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "${TP_DP_CORE_INFRA_CHART_VERSION}" -f - <<EOF
global:
  tibco:
    dataPlaneId: "${DP_INSTANCE_ID}"
    subscriptionId: "sub1"
    serviceAccount: "${DP_INSTANCE_ID}-sa"
    controlPlaneUrl: "https://${CP_MY_DNS_DOMAIN}"
    containerRegistry:
      url: "${TP_CONTAINER_REGISTRY_URL}"
      username: "${TP_CONTAINER_REGISTRY_USER}"
      password: "${TP_CONTAINER_REGISTRY_PASSWORD}"
      repository: "${TP_CONTAINER_REGISTRY_REPOSITORY}"

tp-tibtunnel:
  enabled: true
  configure:
    accessKey: "${TP_DP_ACCESS_KEY}"

tp-provisioner-agent:
  enabled: true

# HAProxy ingress for internal routing (optional)
haproxy:
  enabled: false
EOF
```

**Monitor Data Plane deployment**:

```bash
# Watch pods
kubectl get pods -n ${DP_NAMESPACE} --watch

# Check tibtunnel logs
kubectl logs -n ${DP_NAMESPACE} -l app.kubernetes.io/name=tp-tibtunnel -f

# Check provisioner-agent logs
kubectl logs -n ${DP_NAMESPACE} -l app.kubernetes.io/name=tp-provisioner-agent -f
```

### Step 9.5: Verify Data Plane Deployment

**Check all Data Plane pods are running**:

```bash
kubectl get pods -n ${DP_NAMESPACE}

# Expected pods:
# dp-configure-namespace-otel-userapp-metrics-xxx
# dp-configure-namespace-otel-userapp-traces-xxx
# dp-core-infrastructure-tp-tibtunnel-xxx
# dp-core-infrastructure-tp-provisioner-agent-xxx
```

**Verify Data Plane connection to Control Plane**:

```bash
# Check tibtunnel connection status
kubectl logs -n ${DP_NAMESPACE} -l app.kubernetes.io/name=tp-tibtunnel --tail=50

# Look for messages like:
# "tunnel established successfully"
# "connected to control plane"

# Check provisioner-agent registration
kubectl logs -n ${DP_NAMESPACE} -l app.kubernetes.io/name=tp-provisioner-agent --tail=50

# Look for messages like:
# "registered with control plane"
# "agent started successfully"
```

**Verify Data Plane in Control Plane UI**:

1. Login to Control Plane UI: `https://admin.${CP_MY_DNS_DOMAIN}`
2. Navigate to **Settings** → **Clusters**
3. Your Data Plane cluster should appear with:
   - **Name**: Based on ${DP_INSTANCE_ID}
   - **Status**: Connected (green indicator)
   - **Health**: All health checks passing

### Step 9.6: Provision Capabilities via Control Plane UI

With the Data Plane deployed and connected, you now provision capabilities (BWCE, Flogo, etc.) through the Control Plane UI, **NOT** via Helm charts.

> [!NOTE]
> In 1.18.0, the Control Plane UI may generate updated install commands and values for Data Plane components. Use the generated commands when they differ from this shared guide, especially for namespace-level RBAC, Gateway API endpoint selection, or capability-specific chart versions.

**Steps to provision capabilities**:

1. Login to Control Plane UI
2. Navigate to **Clusters** → Select your Data Plane cluster
3. Click **Capabilities** tab
4. Click **Add Capability**
5. Select capabilities to install:
   - **BusinessWorks Container Edition (BWCE)**
   - **Flogo® Enterprise**
   - **TIBCO Enterprise Message Service™ (EMS)**
6. Configure each capability:
   - **Storage Class**: `azure-files-sc` (for BWCE/Flogo)
   - **Storage Class**: `azure-disk-sc` (for EMS)
   - **Ingress Class**: `nginx` or `traefik`
  - **Gateway API**: Select and provide GatewayClass/Gateway/HTTPRoute details if using the 1.18.0 Gateway API endpoint option instead of ingress
  - **Namespace RBAC**: Confirm the target namespace and role assignments for Application Manager/Application Viewer users
   - **Domain**: Subdomain for app routing (e.g., `apps.${TP_DOMAIN}`)
7. Click **Provision**

The Control Plane will automatically deploy the required Helm charts to the Data Plane cluster.

**Monitor capability provisioning**:

```bash
# Watch for new pods being created
kubectl get pods -n ${DP_NAMESPACE} --watch

# Check for capability-specific deployments
kubectl get deployments -n ${DP_NAMESPACE}
kubectl get statefulsets -n ${DP_NAMESPACE}

# If Gateway API is used for app endpoints, verify the generated routes
kubectl get gatewayclass,gateway,httproute -A
```

**Verify capabilities in Control Plane UI**:

1. Navigate to **Clusters** → Select your Data Plane
2. Click **Capabilities** tab
3. All provisioned capabilities should show **Status: Ready**

**Verify 1.18.0 namespace-level access**:

1. Confirm Application Manager and Application Viewer roles are assigned to the intended namespaces.
2. Test with a non-admin user by deploying or viewing an application only in an authorized namespace.
3. Confirm the same user cannot manage applications in unauthorized namespaces.

---

## Part 10: Post-Deployment Verification

### Step 10.1: Test Control Plane Access

```bash
# Test Control Plane MY domain
curl -k -I https://admin.$CP_MY_DNS_DOMAIN

# Expected: HTTP/2 200 or 302 (redirect to login)

# Test Control Plane tunnel path. In simplified DNS, CP_MY_DNS_DOMAIN and
# CP_TUNNEL_DNS_DOMAIN are the same base domain.
curl -k -I https://admin.$CP_TUNNEL_DNS_DOMAIN/infra/tunnel

# Expected: HTTP/2 200 or similar
```

### Step 10.2: Test Data Plane Connectivity

```bash
# From within the Data Plane namespace, test CP connectivity
kubectl run test-dp-cp-connection --image=curlimages/curl --rm -it --restart=Never -n $TP_DP_NAMESPACE -- \
  curl -k -I https://admin.$CP_MY_DNS_DOMAIN

# Expected: HTTP/2 200 or 302
```

### Step 10.3: Deploy Test BWCE Application

1. Login to Control Plane UI
2. Navigate to **Applications** → **BWCE Apps**
3. Click **Deploy New Application**
4. Select Data Plane: `dp1`
5. Upload a sample BWCE app or use a test app
6. Configure application domain: `myapp.dp1.platform.azure.example.com`
7. Deploy

**Verify Application**:

```bash
# Check application pods
kubectl get pods -n $TP_DP_NAMESPACE | grep bwce

# Test application endpoint
curl -k https://myapp.dp1.platform.azure.example.com/health

# Expected: Application health response
```

### Step 10.4: Check Resource Usage

```bash
# Control Plane resource usage
kubectl top nodes
kubectl top pods -n $TP_CP_NAMESPACE

# Data Plane resource usage
kubectl top pods -n $TP_DP_NAMESPACE

# Check PVC usage
kubectl get pvc -n $TP_CP_NAMESPACE
kubectl get pvc -n $TP_DP_NAMESPACE
```

### Step 10.5: Verify DNS Resolution from Data Plane

```bash
# Test DNS resolution from Data Plane pods
kubectl run dns-test --image=busybox --rm -it --restart=Never -n $TP_DP_NAMESPACE -- \
  nslookup admin.$CP_MY_DNS_DOMAIN

# Expected: Should resolve to Load Balancer IP

kubectl run dns-test --image=busybox --rm -it --restart=Never -n $TP_DP_NAMESPACE -- \
  nslookup admin.$CP_TUNNEL_DNS_DOMAIN

# Expected: Should resolve to Load Balancer IP
```

---

## Part 11: Troubleshooting

### Common Issues and Solutions

#### 1. Missing DBHost in ConfigMap

**Symptom:** During or after Control Plane installation, you encounter an error:
```
Error: missing DBHost key in ConfigMap {namespace}/provider-cp-database-config
```

**Root Cause:** The database configuration was not included in the Helm values during installation. Environment variables alone do not automatically flow into Helm charts unless explicitly referenced in the values.

**Solution:**

1. **Verify your environment variables are set:**
```bash
# Check if DB environment variables are exported
echo "DB Host: ${POSTGRES_HOST}"
echo "DB Port: ${POSTGRES_PORT}"
```

2. **Ensure the Helm values file includes database configuration:**

The values file (cp-values.yaml) **must** include the flat database keys under `global.external`:
```yaml
global:
  external:
    db_host: "${POSTGRES_HOST}"
    db_name: "${POSTGRES_DB:-postgres}"
    db_port: ${POSTGRES_PORT}
    db_username: "${POSTGRES_USER:-postgres}"
    db_password: "${POSTGRES_PASSWORD}"
    db_secret_name: "provider-cp-database-credentials"
    db_ssl_mode: "${POSTGRES_SSL_MODE:-require}"
    db_ssl_root_cert: "/private/tsc/certificates/${POSTGRES_SSL_ROOT_CERT_FILENAME:-db_ssl_root.cert}"
```

  For Azure PostgreSQL, also set `global.tibco.db_ssl_root_cert_secretname` and `global.tibco.db_ssl_root_cert_filename`, and create the CA bundle secret shown in [Step 8.3](#step-83-create-required-kubernetes-secrets).

3. **Verify after deployment:**
```bash
# Check if the ConfigMap contains the DBHost key
kubectl get configmap provider-cp-database-config -n ${CP_INSTANCE_ID}-ns -o yaml | grep -i "host"

# Expected output:
#   DBHost: postgres-cp1-postgresql.cp1-ns.svc.cluster.local  (or your DB host)
```

4. **Fix by redeploying with corrected values:**

Update your `cp-values.yaml` file to include the complete database configuration (see [Step 8.5](#step-85-configure-control-plane-helm-values)), then redeploy:

```bash
helm upgrade --install --wait --timeout 30m \
  -n ${CP_INSTANCE_ID}-ns platform-base tibco-cp-base \
  --labels layer=5 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" \
  --version "${TP_CP_BASE_CHART_VERSION:-1.18.0}" \
  --values cp-values.yaml
```

**Related:** See [Step 8.5: Configure Control Plane Helm Values](#step-85-configure-control-plane-helm-values) for the complete and corrected configuration.

#### 2. Pods Not Starting

**Symptoms**: Pods stuck in `Pending`, `ImagePullBackOff`, or `CrashLoopBackOff`

**Solutions**:

```bash
# Check pod status
kubectl describe pod <pod-name> -n <namespace>

# Check events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Check container logs
kubectl logs <pod-name> -n <namespace> -c <container-name>

# Common fixes:
# - Image pull issues: Verify container registry credentials
# - Resource issues: Check node resources (kubectl describe nodes)
# - Storage issues: Verify storage classes and PVC status
```

#### 3. Ingress Not Working

**Symptoms**: Cannot access Control Plane UI, 404 or connection timeout

**Solutions**:

```bash
# Check ingress resources
kubectl get ingress -n $TP_CP_NAMESPACE

# Check ingress controller logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik -f

# Verify Load Balancer IP
kubectl get svc dp-config-aks-ingress-traefik -n ingress-system

# Test DNS resolution
nslookup admin.$CP_MY_DNS_DOMAIN

# Common fixes:
# - DNS not configured: Add DNS records pointing to Load Balancer IP
# - TLS certificate issues: Verify TLS secrets
# - Ingress class mismatch: Ensure ingressClassName matches controller
```

#### 4. Data Plane Not Connecting to Control Plane

**Symptoms**: Data Plane shows as **Disconnected** in Control Plane UI

**Solutions**:

```bash
# Check Data Plane logs
kubectl logs -n $TP_DP_NAMESPACE -l app.kubernetes.io/component=dp-core-ops -f

# Verify DNS resolution from Data Plane
kubectl run dns-test --image=busybox --rm -it --restart=Never -n $TP_DP_NAMESPACE -- \
  nslookup admin.$CP_MY_DNS_DOMAIN

# Check Data Plane token secret
kubectl get secret tibco-dp-token -n $TP_DP_NAMESPACE

# Verify network connectivity
kubectl run netshoot --image=nicolaka/netshoot --rm -it --restart=Never -n $TP_DP_NAMESPACE -- \
  curl -k -v https://admin.$CP_MY_DNS_DOMAIN

# Common fixes:
# - Invalid token: Re-generate token from Control Plane UI
# - DNS not resolving: Verify DNS records are correct
# - Certificate issues: Check TLS certificate configuration
# - Network policy blocking: Review NetworkPolicies if Calico is enabled
```

#### 5. PostgreSQL Connection Issues

**Symptoms**: Control Plane pods failing with database connection errors

**Solutions**:

```bash
# Test PostgreSQL connection from AKS
kubectl run postgres-test --image=postgres:16 --rm -it --restart=Never -- \
  psql "host=$POSTGRES_HOST port=$POSTGRES_PORT dbname=$POSTGRES_DB user=$POSTGRES_USER password=$POSTGRES_PASSWORD sslmode=require" \
  -c "SELECT version();"

# Check PostgreSQL firewall rules (Azure)
az postgres flexible-server firewall-rule list \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "tibco-platform-db" \
  -o table

# Check PostgreSQL server status
az postgres flexible-server show \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "tibco-platform-db" \
  --query "{Name:name, State:state, Version:version}" -o table

# Common fixes:
# - Firewall blocking: Add AKS subnet to PostgreSQL firewall rules
# - Wrong credentials: Verify POSTGRES_USER and POSTGRES_PASSWORD
# - SSL mode: Ensure db_ssl_mode is set to "require" and the db-ssl-root-cert secret exists
```

#### 6. Storage Issues (PVC Not Binding)

**Symptoms**: PVCs stuck in `Pending` state

**Solutions**:

```bash
# Check PVC status
kubectl get pvc -n <namespace>

# Describe PVC for events
kubectl describe pvc <pvc-name> -n <namespace>

# Check storage classes
kubectl get storageclass

# Check Azure Storage Account
az storage account show \
  --name "$AZURE_STORAGE_ACCOUNT" \
  --resource-group "$AZURE_STORAGE_RESOURCE_GROUP"

# Common fixes:
# - Storage class not found: Verify storage class exists
# - Azure Files secret missing: Create azure-storage-secret
# - Insufficient quota: Check Azure subscription quotas
# - VolumeBindingMode: Check if WaitForFirstConsumer (needs pod to be scheduled)
```

#### 7. Certificate Errors

**Symptoms**: Browser shows certificate errors, ingress TLS not working

**Solutions**:

```bash
# Check TLS secrets
kubectl get secret -n $TP_CP_NAMESPACE | grep tls

# Verify certificate contents
kubectl get secret cp-my-tls-cert -n $TP_CP_NAMESPACE -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -text -noout

# Check certificate expiration
kubectl get secret cp-my-tls-cert -n $TP_CP_NAMESPACE -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -enddate -noout

# For Let's Encrypt certificates
kubectl get certificate -n $TP_CP_NAMESPACE
kubectl describe certificate <cert-name> -n $TP_CP_NAMESPACE

# Common fixes:
# - Expired certificates: Regenerate certificates
# - Wrong domain: Verify certificate CN/SAN matches domain
# - Let's Encrypt challenge failed: Check ingress is accessible from internet
```

### Collecting Diagnostic Information

```bash
# Collect all logs for Control Plane
kubectl logs -n $TP_CP_NAMESPACE --all-containers --prefix > cp-logs.txt

# Collect all logs for Data Plane
kubectl logs -n $TP_DP_NAMESPACE --all-containers --prefix > dp-logs.txt

# Collect pod descriptions
kubectl describe pods -n $TP_CP_NAMESPACE > cp-pods-describe.txt
kubectl describe pods -n $TP_DP_NAMESPACE > dp-pods-describe.txt

# Collect events
kubectl get events -n $TP_CP_NAMESPACE --sort-by='.lastTimestamp' > cp-events.txt
kubectl get events -n $TP_DP_NAMESPACE --sort-by='.lastTimestamp' > dp-events.txt

# Collect cluster info
kubectl cluster-info dump > cluster-info.txt

# Package for support
tar -czf tibco-platform-diagnostics.tar.gz *-logs.txt *-describe.txt *-events.txt cluster-info.txt
```

---

## Summary

You have successfully deployed TIBCO Platform Control Plane and Data Plane on Azure Kubernetes Service!

### What You Deployed

- ✅ AKS cluster with 3+ nodes
- ✅ Azure Disk and Azure Files storage classes
- ✅ Traefik ingress controller with Azure Load Balancer
- ✅ Azure Database for PostgreSQL Flexible Server
- ✅ DNS records for CP and DP domains
- ✅ TLS certificates (self-signed or Let's Encrypt)
- ✅ TIBCO Platform Control Plane
- ✅ TIBCO Platform Data Plane with BWCE, Flogo, and EMS capabilities

### Access Information

- **Control Plane UI**: https://admin.${CP_MY_DNS_DOMAIN}
- **Admin Username**: admin
- **Admin Password**: ${TP_CP_ADMIN_PASSWORD}

### Next Steps

1. **License Configuration**: Upload TIBCO Platform license in Control Plane UI
2. **User Management**: Create additional users and assign roles
3. **Deploy Applications**: Deploy BWCE and Flogo applications via Control Plane
4. **Observability**: Set up monitoring with Elastic ECK and Prometheus (see [how-to-dp-aks-observability](./how-to-dp-aks-observability))
5. **Production Hardening**:
   - Replace self-signed certificates with Let's Encrypt or corporate CA
   - Configure backup and disaster recovery
   - Set up network policies for enhanced security
   - Enable Azure Monitor for AKS
   - Configure autoscaling

### Useful Commands

```bash
# View Control Plane status
kubectl get pods -n $TP_CP_NAMESPACE

# View Data Plane status
kubectl get pods -n $TP_DP_NAMESPACE

# View ingress
kubectl get ingress -A

# View all resources
kubectl get all -n $TP_CP_NAMESPACE
kubectl get all -n $TP_DP_NAMESPACE

# Upgrade Control Plane
helm upgrade tibco-cp tibco-platform/tibco-platform-cp \
  --namespace $TP_CP_NAMESPACE \
  --values cp-values.yaml

# Upgrade Data Plane
helm upgrade tibco-dp tibco-platform/tibco-platform-dp \
  --namespace $TP_DP_NAMESPACE \
  --values dp-values.yaml
```

---

## References

- [TIBCO Platform 1.18.0 Documentation](https://docs.tibco.com/pub/platform-cp/1.18.0/doc/html/Default.htm)
- [TIBCO Platform 1.17.0 Documentation](https://docs.tibco.com/pub/platform-cp/1.17.0/doc/html/Default.htm)
- [TIBCO Helm Charts GitHub](https://github.com/TIBCOSoftware/tp-helm-charts)
- [Azure Kubernetes Service Documentation](https://learn.microsoft.com/en-us/azure/aks/)
- [Prerequisites Checklist](./prerequisites-checklist-for-customer)
- [DNS Configuration Guide](./how-to-add-dns-records-aks-azure)
- [Observability Setup Guide](./how-to-dp-aks-observability)

---

**Document Version**: 1.0  
**Last Updated**: June 11, 2026
**Maintained By**: TIBCO Platform Team
