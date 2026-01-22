# TIBCO Platform Data Plane Only Setup on AKS

**Document Purpose**: Step-by-step guide for deploying TIBCO Platform Data Plane on Azure Kubernetes Service (AKS) connecting to a SaaS Control Plane or existing remote Control Plane.

**Target Audience**: DevOps engineers, Platform administrators

**Use Case**: Hybrid cloud deployments where Control Plane runs in SaaS or different environment, and Data Plane runs on customer's AKS cluster

**Estimated Time**: 2-3 hours

**Last Updated**: January 22, 2026

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Part 1: Environment Preparation](#part-1-environment-preparation)
- [Part 2: AKS Cluster Setup](#part-2-aks-cluster-setup)
- [Part 3: Storage Configuration](#part-3-storage-configuration)
- [Part 4: Ingress Controller Setup](#part-4-ingress-controller-setup)
- [Part 5: DNS Configuration](#part-5-dns-configuration)
- [Part 6: Data Plane Registration](#part-6-data-plane-registration)
- [Part 7: Data Plane Deployment](#part-7-data-plane-deployment)
- [Part 8: Capability Provisioning](#part-8-capability-provisioning)
- [Part 9: Verification](#part-9-verification)
- [Part 10: Troubleshooting](#part-10-troubleshooting)

---

## Overview

This guide covers deploying **TIBCO Platform Data Plane only** on AKS, connecting to an existing Control Plane (either SaaS or self-hosted in a different environment).

### Key Differences from Full Deployment

- ✅ **No Control Plane deployment** on AKS
- ✅ **No PostgreSQL** required (managed by Control Plane)
- ✅ **Simplified networking** - only Data Plane domains needed
- ✅ **DNS resolution required** - Data Plane communicates with Control Plane via secure tunnels over DNS
- ✅ **Smaller cluster** - 3-5 nodes with Standard_D4s_v3 (vs Standard_D8s_v3 for CP)

### Communication Architecture

**Critical**: Data Plane and Control Plane communicate via **secure tunnels over DNS**, NOT VNet peering:
- Data Plane connects to Control Plane's `my` domain (HTTPS API endpoint)
- Data Plane establishes secure WebSocket tunnel via Control Plane's `tunnel` domain
- BWCE and Flogo applications use ingress controllers registered in DNS for external access
- No VNet peering needed between Data Plane AKS and Control Plane environment

---

## Architecture

```mermaid
graph TB
    subgraph "SaaS Control Plane / Remote Environment"
        CP[TIBCO Control Plane]
        CP_MY[my.cp.saas.tibco.com]
        CP_TUNNEL[tunnel.cp.saas.tibco.com]
    end
    
    subgraph "Customer Azure Cloud"
        subgraph "Data Plane AKS Cluster"
            DP[Data Plane Core]
            BWCE[BWCE Runtime]
            FLOGO[Flogo Runtime]
            EMS[EMS Runtime]
            
            INGRESS[Ingress Controller<br/>Traefik]
            STORAGE[Azure Storage<br/>Files + Disk]
        end
        
        LB[Azure Load Balancer]
        DNS[Azure DNS<br/>dp.customer.com]
    end
    
    USERS[End Users] -->|HTTPS| LB
    LB -->|App Traffic| INGRESS
    INGRESS -->|Route| BWCE
    INGRESS -->|Route| FLOGO
    
    DP -.->|Secure Tunnel<br/>via DNS| CP_MY
    DP -.->|WebSocket<br/>via DNS| CP_TUNNEL
    
    DP -->|PVC| STORAGE
    BWCE -->|PVC| STORAGE
    FLOGO -->|PVC| STORAGE
    EMS -->|PVC| STORAGE
    
    DNS -.->|Wildcard *.dp| LB
```

**Key Points**:
- Data Plane initiates **outbound HTTPS connections** to Control Plane
- Control Plane domains must be **resolvable via DNS** from Data Plane cluster
- Applications deployed on Data Plane use **local ingress** registered in customer's DNS
- No inbound connections from Control Plane to Data Plane required

---

## Prerequisites

### 1. Control Plane Information

You need the following information from your Control Plane:

| Information | Example | Where to Get It |
|-------------|---------|-----------------|
| **Control Plane MY Domain** | `my.cp.saas.tibco.com` | Control Plane administrator |
| **Control Plane TUNNEL Domain** | `tunnel.cp.saas.tibco.com` | Control Plane administrator |
| **Data Plane Registration Token** | `eyJhbGc...` | Generated from Control Plane UI |
| **Container Registry Credentials** | Username + Password | TIBCO account team |

### 2. Azure Resources

- Azure subscription with Owner or Contributor role
- Ability to create AKS clusters
- Azure DNS zone (or external DNS provider)
- Azure Storage Account (or ability to create one)

### 3. Network Requirements

**Critical**: Data Plane must have **outbound HTTPS (443) access** to Control Plane domains:

```bash
# Test connectivity from your network
curl -I https://my.cp.saas.tibco.com
curl -I https://tunnel.cp.saas.tibco.com

# Both should return HTTP 200 or 302
```

**DNS Resolution**:
- Data Plane cluster must resolve Control Plane domains
- No VNet peering required
- No inbound connectivity required

### 4. Tools Required

| Tool | Version | Purpose |
|------|---------|---------|
| `az` (Azure CLI) | 2.50.0+ | Azure resource management |
| `kubectl` | Latest stable | Kubernetes cluster management |
| `helm` | 3.17.0+ | Chart deployment |
| `curl` | Latest | Testing connectivity |

---

## Part 1: Environment Preparation

### Step 1.1: Set Environment Variables

```bash
# Navigate to workshop directory
cd /path/to/workshop-tp-aks

# Create Data Plane specific environment file
cat > dp-env.sh <<'EOF'
#!/bin/bash

# Azure Configuration
export AZURE_SUBSCRIPTION_ID="your-subscription-id"
export AZURE_REGION="eastus"
export AZURE_RESOURCE_GROUP="tibco-dp-rg"

# AKS Configuration (Data Plane Only)
export AKS_CLUSTER_NAME="tibco-dp-aks"
export AKS_NODE_COUNT=3
export AKS_NODE_SIZE="Standard_D4s_v3"  # Smaller than CP

# Control Plane Information (SaaS or Remote)
export TP_CP_MY_DOMAIN="my.cp.saas.tibco.com"
export TP_CP_TUNNEL_DOMAIN="tunnel.cp.saas.tibco.com"

# Data Plane Configuration
export TP_DP_INSTANCE_ID="dp-customer1"
export TP_DP_NAMESPACE="tibco-dp"
export TP_DP_DOMAIN="dp.customer.com"  # Your customer domain for apps

# Storage Configuration
export AZURE_STORAGE_ACCOUNT="tibcodpsa"
export AZURE_STORAGE_RESOURCE_GROUP="$AZURE_RESOURCE_GROUP"

# Container Registry (from TIBCO)
export CONTAINER_REGISTRY_SERVER="csgprduswrepoedge.jfrog.io"
export CONTAINER_REGISTRY_USERNAME="your-username"
export CONTAINER_REGISTRY_PASSWORD="your-password"

# Data Plane Token (get from Control Plane UI)
export TP_DP_TOKEN=""  # Will be filled after registration

# Ingress Configuration
export INGRESS_CLASS="traefik"

echo "Environment variables loaded for Data Plane: $TP_DP_INSTANCE_ID"
EOF

# Source the environment
source dp-env.sh
```

### Step 1.2: Login to Azure

```bash
# Login to Azure
az login

# Set subscription
az account set --subscription "$AZURE_SUBSCRIPTION_ID"

# Verify
az account show --query "{Name:name, ID:id}" -o table
```

### Step 1.3: Verify Control Plane Connectivity

**Critical Step**: Ensure you can reach Control Plane domains:

```bash
# Test MY domain
echo "Testing Control Plane MY domain..."
curl -I https://$TP_CP_MY_DOMAIN

# Test TUNNEL domain
echo "Testing Control Plane TUNNEL domain..."
curl -I https://$TP_CP_TUNNEL_DOMAIN

# Expected: HTTP/2 200 or 302 for both
```

If these fail, check:
- DNS resolution: `nslookup $TP_CP_MY_DOMAIN`
- Firewall rules allowing outbound HTTPS (443)
- Proxy configuration if applicable

---

## Part 2: AKS Cluster Setup

### Step 2.1: Create Resource Group

```bash
# Create resource group
az group create \
  --name "$AZURE_RESOURCE_GROUP" \
  --location "$AZURE_REGION"
```

### Step 2.2: Create AKS Cluster

**Data Plane Optimized Configuration**:

```bash
# Create AKS cluster with Kubenet (simpler for DP-only)
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
  --max-count 8 \
  --tags "Environment=Production" "Component=DataPlane" "Application=TIBCOPlatform"

# Note: Cluster creation takes 5-10 minutes
```

**Optional: Use Azure CNI for advanced networking**:

```bash
# Create VNet first
az network vnet create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "tibco-dp-vnet" \
  --address-prefixes 10.5.0.0/16 \
  --subnet-name "aks-subnet" \
  --subnet-prefixes 10.5.0.0/20

# Get subnet ID
SUBNET_ID=$(az network vnet subnet show \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --vnet-name "tibco-dp-vnet" \
  --name "aks-subnet" \
  --query id -o tsv)

# Create AKS with Azure CNI
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
  --max-count 8
```

### Step 2.3: Get AKS Credentials

```bash
# Get credentials
az aks get-credentials \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$AKS_CLUSTER_NAME" \
  --overwrite-existing

# Verify connection
kubectl get nodes

# Expected: 3 nodes in Ready state
```

---

## Part 3: Storage Configuration

### Step 3.1: Create Azure Storage Account

```bash
# Create storage account for Azure Files (BWCE/Flogo)
az storage account create \
  --name "$AZURE_STORAGE_ACCOUNT" \
  --resource-group "$AZURE_STORAGE_RESOURCE_GROUP" \
  --location "$AZURE_REGION" \
  --sku Premium_LRS \
  --kind FileStorage \
  --https-only true

# Get storage key
AZURE_STORAGE_KEY=$(az storage account keys list \
  --account-name "$AZURE_STORAGE_ACCOUNT" \
  --resource-group "$AZURE_STORAGE_RESOURCE_GROUP" \
  --query "[0].value" -o tsv)

export AZURE_STORAGE_KEY
```

### Step 3.2: Deploy Storage Classes

**Add TIBCO Helm Repo**:

```bash
helm repo add tibco-platform https://tibcosoftware.github.io/tp-helm-charts
helm repo update
```

**Deploy Azure Disk Storage Class** (for EMS):

```bash
# Azure Disk for EMS persistent volumes
cat > azure-disk-values.yaml <<EOF
storageClass:
  name: azure-disk-sc
  provisioner: disk.csi.azure.com
  parameters:
    storageaccounttype: Premium_LRS
    kind: Managed
  reclaimPolicy: Retain
  volumeBindingMode: WaitForFirstConsumer
  allowVolumeExpansion: true
EOF

helm install azure-disk-sc tibco-platform/dp-config-aks \
  --namespace kube-system \
  --values azure-disk-values.yaml \
  --set storageClass.enabled=true \
  --set ingressClass.enabled=false
```

**Deploy Azure Files Storage Class** (for BWCE/Flogo):

```bash
# Create secret for Azure Files
kubectl create secret generic azure-storage-secret \
  --from-literal=azurestorageaccountname="$AZURE_STORAGE_ACCOUNT" \
  --from-literal=azurestorageaccountkey="$AZURE_STORAGE_KEY" \
  --namespace kube-system

# Azure Files for BWCE/Flogo shared storage
cat > azure-files-values.yaml <<EOF
storageClass:
  name: azure-files-sc
  provisioner: file.csi.azure.com
  parameters:
    storageAccount: $AZURE_STORAGE_ACCOUNT
    resourceGroup: $AZURE_STORAGE_RESOURCE_GROUP
    skuName: Premium_LRS
  reclaimPolicy: Retain
  volumeBindingMode: Immediate
  allowVolumeExpansion: true
  mountOptions:
    - dir_mode=0777
    - file_mode=0777
    - uid=0
    - gid=0
    - mfsymlinks
    - cache=strict
    - actimeo=30
EOF

helm install azure-files-sc tibco-platform/dp-config-aks \
  --namespace kube-system \
  --values azure-files-values.yaml \
  --set storageClass.enabled=true \
  --set ingressClass.enabled=false
```

### Step 3.3: Verify Storage Classes

```bash
kubectl get storageclass

# Expected:
# azure-disk-sc    disk.csi.azure.com   Retain   WaitForFirstConsumer   true
# azure-files-sc   file.csi.azure.com   Retain   Immediate              true
```

---

## Part 4: Ingress Controller Setup

### Step 4.1: Install Traefik Ingress Controller

**Data Plane uses ingress for BWCE/Flogo application traffic**:

```bash
# Add Traefik Helm repo
helm repo add traefik https://traefik.github.io/charts
helm repo update

# Create Traefik values
cat > traefik-values.yaml <<EOF
deployment:
  replicas: 2

service:
  type: LoadBalancer
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /ping

ports:
  web:
    redirectTo:
      port: websecure
  websecure:
    tls:
      enabled: true

ingressClass:
  enabled: true
  isDefaultClass: true

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

resources:
  requests:
    cpu: "250m"
    memory: "256Mi"
  limits:
    cpu: "1000m"
    memory: "1Gi"
EOF

# Create namespace
kubectl create namespace traefik

# Install Traefik
helm install traefik traefik/traefik \
  --namespace traefik \
  --values traefik-values.yaml \
  --version 33.4.0

# Wait for Load Balancer IP
kubectl get svc traefik -n traefik --watch
```

### Step 4.2: Get Load Balancer IP

```bash
# Get external IP
export INGRESS_LOAD_BALANCER_IP=$(kubectl get svc traefik -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Ingress Load Balancer IP: $INGRESS_LOAD_BALANCER_IP"

# Save to environment file
echo "export INGRESS_LOAD_BALANCER_IP=$INGRESS_LOAD_BALANCER_IP" >> dp-env.sh
```

---

## Part 5: DNS Configuration

### Step 5.1: Create DNS Zone (if needed)

```bash
# Create Azure DNS zone for Data Plane apps
az network dns zone create \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$TP_DP_DOMAIN"

# Get name servers
az network dns zone show \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --name "$TP_DP_DOMAIN" \
  --query nameServers -o table

# Delegate these name servers in your parent domain
```

### Step 5.2: Create Wildcard DNS Record

**BWCE and Flogo apps use subdomains under Data Plane domain**:

```bash
# Create wildcard A record
az network dns record-set a add-record \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --zone-name "$TP_DP_DOMAIN" \
  --record-set-name "*" \
  --ipv4-address "$INGRESS_LOAD_BALANCER_IP"

# Verify
az network dns record-set a list \
  --resource-group "$AZURE_RESOURCE_GROUP" \
  --zone-name "$TP_DP_DOMAIN" \
  -o table
```

### Step 5.3: Verify DNS Resolution

```bash
# Test wildcard DNS (wait 1-2 minutes for propagation)
nslookup myapp.$TP_DP_DOMAIN

# Should resolve to: $INGRESS_LOAD_BALANCER_IP
```

### Step 5.4: Verify Control Plane DNS Resolution

**Critical**: Data Plane must resolve Control Plane domains:

```bash
# Test from your workstation
nslookup $TP_CP_MY_DOMAIN
nslookup $TP_CP_TUNNEL_DOMAIN

# Both should resolve successfully
```

---

## Part 6: Data Plane Registration

### Step 6.1: Access Control Plane UI

1. Navigate to your Control Plane URL (SaaS or self-hosted)
2. Login with your credentials

### Step 6.2: Register Data Plane

**In Control Plane UI**:

1. Navigate to **Settings** → **Data Planes**
2. Click **Register Data Plane**
3. Fill in the registration form:
   - **Data Plane ID**: `dp-customer1` (use value from `$TP_DP_INSTANCE_ID`)
   - **Description**: "Customer AKS Data Plane"
   - **Location**: "Azure East US" (or your region)
   - **Environment**: Production or Development
4. Click **Generate Token**
5. Copy the generated token - **save it securely**

### Step 6.3: Save Data Plane Token

```bash
# Set the token (paste the value from Control Plane UI)
export TP_DP_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."

# Save to environment file
echo "export TP_DP_TOKEN=\"$TP_DP_TOKEN\"" >> dp-env.sh

# Verify token is set
echo "Token length: ${#TP_DP_TOKEN}"
# Should be 500+ characters
```

---

## Part 7: Data Plane Deployment

### Step 7.1: Create Data Plane Namespace

```bash
# Create namespace
kubectl create namespace $TP_DP_NAMESPACE

# Create service account
kubectl create serviceaccount tibco-dp-sa -n $TP_DP_NAMESPACE
```

### Step 7.2: Create Kubernetes Secrets

**1. Container Registry Secret**:

```bash
kubectl create secret docker-registry tibco-container-registry-credentials \
  --docker-server="$CONTAINER_REGISTRY_SERVER" \
  --docker-username="$CONTAINER_REGISTRY_USERNAME" \
  --docker-password="$CONTAINER_REGISTRY_PASSWORD" \
  --namespace $TP_DP_NAMESPACE
```

**2. Data Plane Token Secret**:

```bash
kubectl create secret generic tibco-dp-token \
  --from-literal=token="$TP_DP_TOKEN" \
  --namespace $TP_DP_NAMESPACE

# Verify
kubectl get secret tibco-dp-token -n $TP_DP_NAMESPACE
```

### Step 7.3: Configure Data Plane Helm Values

```bash
cat > dp-values.yaml <<EOF
global:
  tibco:
    # Data Plane Identity
    dataPlaneInstanceId: "$TP_DP_INSTANCE_ID"
    
    # Control Plane Connection (SaaS or Remote)
    controlPlaneUrl: "https://$TP_CP_MY_DOMAIN"
    
    # Container Registry
    containerRegistry:
      url: "$CONTAINER_REGISTRY_SERVER"
      username: "$CONTAINER_REGISTRY_USERNAME"
      password: "$CONTAINER_REGISTRY_PASSWORD"
    
    # Service Account
    serviceAccount: "tibco-dp-sa"
    
    # Logging
    logging:
      fluentbit:
        enabled: true

# Data Plane Configuration
dataPlane:
  # Control Plane Connection
  controlPlane:
    myDomain: "$TP_CP_MY_DOMAIN"
    tunnelDomain: "$TP_CP_TUNNEL_DOMAIN"
    tokenSecret: "tibco-dp-token"
    tokenSecretKey: "token"
  
  # Data Plane Domain (for BWCE/Flogo apps)
  domain: "$TP_DP_DOMAIN"
  ingressClassName: "$INGRESS_CLASS"
  
  # Capabilities to Enable
  capabilities:
    # BWCE (BusinessWorks Container Edition)
    bwce:
      enabled: true
      storageClassName: "azure-files-sc"
      resources:
        requests:
          cpu: "500m"
          memory: "1Gi"
        limits:
          cpu: "2000m"
          memory: "4Gi"
    
    # Flogo
    flogo:
      enabled: true
      storageClassName: "azure-files-sc"
      resources:
        requests:
          cpu: "500m"
          memory: "1Gi"
        limits:
          cpu: "2000m"
          memory: "4Gi"
    
    # EMS (Enterprise Messaging Service)
    ems:
      enabled: true
      storageClassName: "azure-disk-sc"
      resources:
        requests:
          cpu: "500m"
          memory: "2Gi"
        limits:
          cpu: "2000m"
          memory: "4Gi"

# Storage Configuration
storage:
  storageClassName: "azure-disk-sc"

# Ingress Configuration
ingress:
  enabled: true
  ingressClassName: "$INGRESS_CLASS"
  
  # Annotations for Azure Load Balancer
  annotations:
    kubernetes.io/ingress.class: "$INGRESS_CLASS"

# Network Policy (optional - for enhanced security)
networkPolicy:
  enabled: false
  # Enable if using Calico or Azure Network Policies

# Resource Limits for Data Plane Core
resources:
  requests:
    cpu: "1000m"
    memory: "2Gi"
  limits:
    cpu: "2000m"
    memory: "4Gi"

# High Availability
replicaCount: 2

# Pod Disruption Budget
podDisruptionBudget:
  enabled: true
  minAvailable: 1
EOF
```

### Step 7.4: Deploy Data Plane

```bash
# Update Helm repos
helm repo update

# Install Data Plane
helm install tibco-dp tibco-platform/tibco-platform-dp \
  --namespace $TP_DP_NAMESPACE \
  --values dp-values.yaml \
  --timeout 20m \
  --wait

# Monitor deployment
kubectl get pods -n $TP_DP_NAMESPACE --watch
```

**Expected deployment time**: 8-12 minutes

### Step 7.5: Monitor Deployment Progress

```bash
# Watch pods starting
kubectl get pods -n $TP_DP_NAMESPACE -w

# Check Data Plane logs
kubectl logs -n $TP_DP_NAMESPACE -l app.kubernetes.io/component=dp-core-ops -f

# Look for successful connection messages:
# - "Connected to Control Plane"
# - "Tunnel established"
# - "Capabilities registered"
```

---

## Part 8: Capability Provisioning

### Step 8.1: Verify Data Plane in Control Plane UI

1. Login to Control Plane UI
2. Navigate to **Settings** → **Data Planes**
3. Verify Data Plane status:
   - **Status**: Connected (green indicator)
   - **ID**: `dp-customer1`
   - **Capabilities**: BWCE, Flogo, EMS

### Step 8.2: Check Capability Status

**In Control Plane UI**:

1. Go to **Capabilities** section
2. Verify each capability shows as **Available**:
   - ✅ BWCE
   - ✅ Flogo
   - ✅ EMS

**Via kubectl**:

```bash
# Check Data Plane pods
kubectl get pods -n $TP_DP_NAMESPACE

# Expected pods:
# dp-core-ops-...           Running
# dp-bwce-provisioner-...   Running
# dp-flogo-provisioner-...  Running
# dp-ems-provisioner-...    Running

# Check capability services
kubectl get svc -n $TP_DP_NAMESPACE
```

### Step 8.3: Deploy Test Application

**Via Control Plane UI**:

1. Navigate to **Applications** → **BWCE Apps**
2. Click **Deploy New Application**
3. Select Data Plane: `dp-customer1`
4. Upload a sample BWCE app or select from catalog
5. Configure:
   - **App Name**: `hello-world`
   - **Domain**: `hello.dp.customer.com`
   - **Replicas**: 1
6. Click **Deploy**

**Monitor Deployment**:

```bash
# Watch application pods starting
kubectl get pods -n $TP_DP_NAMESPACE | grep bwce

# Expected: 
# bwce-hello-world-...   Running
```

---

## Part 9: Verification

### Step 9.1: Test Data Plane Connectivity to Control Plane

```bash
# Test MY domain connectivity from within cluster
kubectl run test-cp-my --image=curlimages/curl --rm -it --restart=Never -n $TP_DP_NAMESPACE -- \
  curl -k -I https://$TP_CP_MY_DOMAIN

# Expected: HTTP/2 200 or 302

# Test TUNNEL domain connectivity
kubectl run test-cp-tunnel --image=curlimages/curl --rm -it --restart=Never -n $TP_DP_NAMESPACE -- \
  curl -k -I https://$TP_CP_TUNNEL_DOMAIN

# Expected: HTTP/2 200
```

### Step 9.2: Test DNS Resolution from Data Plane

```bash
# Test Control Plane DNS resolution
kubectl run dns-test --image=busybox --rm -it --restart=Never -n $TP_DP_NAMESPACE -- \
  nslookup $TP_CP_MY_DOMAIN

# Expected: Should resolve successfully

kubectl run dns-test --image=busybox --rm -it --restart=Never -n $TP_DP_NAMESPACE -- \
  nslookup $TP_CP_TUNNEL_DOMAIN

# Expected: Should resolve successfully
```

### Step 9.3: Test Application Access

```bash
# Test deployed BWCE application
curl -k https://hello.$TP_DP_DOMAIN/health

# Expected: Application health response

# Or use browser:
echo "Application URL: https://hello.$TP_DP_DOMAIN"
```

### Step 9.4: Check Resource Usage

```bash
# Node resource usage
kubectl top nodes

# Data Plane pod resource usage
kubectl top pods -n $TP_DP_NAMESPACE

# Check PVC usage
kubectl get pvc -n $TP_DP_NAMESPACE
```

### Step 9.5: Verify Logs in Control Plane

**In Control Plane UI**:

1. Navigate to **Observability** → **Logs**
2. Filter by Data Plane: `dp-customer1`
3. Verify logs are being collected from Data Plane

---

## Part 10: Troubleshooting

### Issue 1: Data Plane Not Connecting to Control Plane

**Symptoms**: Data Plane shows **Disconnected** in Control Plane UI

**Diagnosis**:

```bash
# Check Data Plane logs
kubectl logs -n $TP_DP_NAMESPACE -l app.kubernetes.io/component=dp-core-ops --tail=100

# Look for errors related to:
# - DNS resolution failures
# - Certificate errors
# - Authentication failures (invalid token)
# - Network connectivity issues
```

**Solutions**:

1. **DNS Resolution Issue**:
   ```bash
   # Test DNS from within cluster
   kubectl run dns-test --image=busybox --rm -it --restart=Never -n $TP_DP_NAMESPACE -- \
     nslookup $TP_CP_MY_DOMAIN
   
   # If fails: Check DNS server configuration in cluster
   kubectl get configmap coredns -n kube-system -o yaml
   ```

2. **Invalid Token**:
   ```bash
   # Regenerate token from Control Plane UI
   # Update secret
   kubectl delete secret tibco-dp-token -n $TP_DP_NAMESPACE
   kubectl create secret generic tibco-dp-token \
     --from-literal=token="NEW_TOKEN_HERE" \
     --namespace $TP_DP_NAMESPACE
   
   # Restart Data Plane pods
   kubectl rollout restart deployment -n $TP_DP_NAMESPACE
   ```

3. **Network Connectivity**:
   ```bash
   # Test HTTPS connectivity from pod
   kubectl run netshoot --image=nicolaka/netshoot --rm -it --restart=Never -n $TP_DP_NAMESPACE -- \
     curl -v https://$TP_CP_MY_DOMAIN
   
   # Check for:
   # - Firewall blocking outbound HTTPS
   # - Proxy configuration needed
   # - NSG rules blocking traffic
   ```

### Issue 2: Capabilities Not Showing as Available

**Symptoms**: BWCE, Flogo, or EMS showing as **Unavailable**

**Diagnosis**:

```bash
# Check capability provisioner pods
kubectl get pods -n $TP_DP_NAMESPACE | grep provisioner

# Check specific capability logs
kubectl logs -n $TP_DP_NAMESPACE -l app=dp-bwce-provisioner --tail=50
kubectl logs -n $TP_DP_NAMESPACE -l app=dp-flogo-provisioner --tail=50
kubectl logs -n $TP_DP_NAMESPACE -l app=dp-ems-provisioner --tail=50
```

**Solutions**:

1. **Storage Class Issues**:
   ```bash
   # Verify storage classes exist
   kubectl get storageclass azure-files-sc azure-disk-sc
   
   # If missing, redeploy storage classes (see Part 3)
   ```

2. **Resource Limits**:
   ```bash
   # Check node resources
   kubectl describe nodes | grep -A 5 "Allocated resources"
   
   # If insufficient: Add more nodes or increase node size
   az aks scale \
     --resource-group "$AZURE_RESOURCE_GROUP" \
     --name "$AKS_CLUSTER_NAME" \
     --node-count 5
   ```

### Issue 3: Application Not Accessible

**Symptoms**: Cannot access deployed BWCE/Flogo application

**Diagnosis**:

```bash
# Check application pod status
kubectl get pods -n $TP_DP_NAMESPACE | grep bwce

# Check ingress resources
kubectl get ingress -n $TP_DP_NAMESPACE

# Check ingress controller logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik --tail=100
```

**Solutions**:

1. **DNS Not Resolving**:
   ```bash
   # Test DNS resolution
   nslookup hello.$TP_DP_DOMAIN
   
   # If fails: Check DNS records
   az network dns record-set a list \
     --resource-group "$AZURE_RESOURCE_GROUP" \
     --zone-name "$TP_DP_DOMAIN" \
     -o table
   
   # Recreate wildcard record if needed
   az network dns record-set a add-record \
     --resource-group "$AZURE_RESOURCE_GROUP" \
     --zone-name "$TP_DP_DOMAIN" \
     --record-set-name "*" \
     --ipv4-address "$INGRESS_LOAD_BALANCER_IP"
   ```

2. **Ingress Not Created**:
   ```bash
   # Check if ingress exists
   kubectl get ingress -n $TP_DP_NAMESPACE
   
   # If missing: Check application deployment in Control Plane UI
   # Verify domain configuration matches $TP_DP_DOMAIN
   ```

### Issue 4: Pods in CrashLoopBackOff

**Diagnosis**:

```bash
# Describe pod to see events
kubectl describe pod <pod-name> -n $TP_DP_NAMESPACE

# Check pod logs
kubectl logs <pod-name> -n $TP_DP_NAMESPACE --previous
```

**Solutions**:

1. **Image Pull Errors**:
   ```bash
   # Verify container registry secret
   kubectl get secret tibco-container-registry-credentials -n $TP_DP_NAMESPACE
   
   # If missing or incorrect:
   kubectl delete secret tibco-container-registry-credentials -n $TP_DP_NAMESPACE
   kubectl create secret docker-registry tibco-container-registry-credentials \
     --docker-server="$CONTAINER_REGISTRY_SERVER" \
     --docker-username="$CONTAINER_REGISTRY_USERNAME" \
     --docker-password="$CONTAINER_REGISTRY_PASSWORD" \
     --namespace $TP_DP_NAMESPACE
   ```

2. **Insufficient Resources**:
   ```bash
   # Check node resources
   kubectl top nodes
   
   # If nodes are full: Scale cluster
   az aks scale \
     --resource-group "$AZURE_RESOURCE_GROUP" \
     --name "$AKS_CLUSTER_NAME" \
     --node-count 5
   ```

### Collecting Diagnostic Information

```bash
# Create diagnostics directory
mkdir -p tibco-dp-diagnostics

# Collect Data Plane logs
kubectl logs -n $TP_DP_NAMESPACE --all-containers --prefix > tibco-dp-diagnostics/dp-logs.txt

# Collect pod descriptions
kubectl describe pods -n $TP_DP_NAMESPACE > tibco-dp-diagnostics/dp-pods-describe.txt

# Collect events
kubectl get events -n $TP_DP_NAMESPACE --sort-by='.lastTimestamp' > tibco-dp-diagnostics/dp-events.txt

# Collect ingress info
kubectl get ingress -n $TP_DP_NAMESPACE -o yaml > tibco-dp-diagnostics/ingress.yaml

# Collect service info
kubectl get svc -n $TP_DP_NAMESPACE -o yaml > tibco-dp-diagnostics/services.yaml

# Package for support
tar -czf tibco-dp-diagnostics.tar.gz tibco-dp-diagnostics/

echo "Diagnostics package created: tibco-dp-diagnostics.tar.gz"
```

---

## Summary

You have successfully deployed TIBCO Platform Data Plane on AKS connected to a SaaS or remote Control Plane!

### What You Deployed

- ✅ AKS cluster optimized for Data Plane (3-5 nodes, Standard_D4s_v3)
- ✅ Azure Disk and Azure Files storage classes
- ✅ Traefik ingress controller
- ✅ DNS configuration for application domains
- ✅ TIBCO Platform Data Plane with secure tunnel to Control Plane
- ✅ BWCE, Flogo, and EMS capabilities

### Key Architecture Points

- **No VNet peering required** - Data Plane connects to Control Plane via secure HTTPS tunnels over DNS
- **Outbound connectivity only** - Data Plane initiates all connections to Control Plane
- **DNS is critical** - Both Control Plane domains and Data Plane app domains must be properly configured
- **Applications use local ingress** - BWCE/Flogo apps run on Data Plane with customer-managed DNS

### Access Information

- **Control Plane UI**: Your SaaS or remote Control Plane URL
- **Data Plane ID**: `dp-customer1`
- **Application Domain**: `*.dp.customer.com`

### Next Steps

1. **Deploy Production Applications**: Use Control Plane UI to deploy BWCE and Flogo apps
2. **Configure TLS Certificates**: Replace with Let's Encrypt or corporate CA certificates
3. **Enable Observability**: Set up log forwarding and metrics collection (see [how-to-dp-aks-observability.md](how-to-dp-aks-observability.md))
4. **Production Hardening**:
   - Enable network policies for pod-to-pod security
   - Configure pod security policies
   - Set up backup for application PVCs
   - Enable Azure Monitor for AKS
5. **Scaling**:
   - Configure horizontal pod autoscaling for applications
   - Enable cluster autoscaler for nodes
   - Monitor resource usage and adjust node sizes

### Useful Commands

```bash
# Check Data Plane status
kubectl get pods -n $TP_DP_NAMESPACE

# View Data Plane logs
kubectl logs -n $TP_DP_NAMESPACE -l app.kubernetes.io/component=dp-core-ops -f

# View applications
kubectl get pods -n $TP_DP_NAMESPACE | grep -E "bwce|flogo"

# Check ingress
kubectl get ingress -n $TP_DP_NAMESPACE

# Upgrade Data Plane
helm upgrade tibco-dp tibco-platform/tibco-platform-dp \
  --namespace $TP_DP_NAMESPACE \
  --values dp-values.yaml

# Scale Data Plane replicas
kubectl scale deployment dp-core-ops -n $TP_DP_NAMESPACE --replicas=3
```

---

## References

- [TIBCO Platform Documentation](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm)
- [Prerequisites Checklist](prerequisites-checklist-for-customer.md)
- [Complete CP+DP Setup Guide](how-to-cp-and-dp-aks-setup-guide.md)
- [DNS Configuration Guide](how-to-add-dns-records-aks-azure.md)
- [Observability Setup](how-to-dp-aks-observability.md)
- [Azure Kubernetes Service Documentation](https://learn.microsoft.com/en-us/azure/aks/)

---

**Document Version**: 1.0  
**Last Updated**: January 22, 2026  
**Maintained By**: TIBCO Platform Team
