# Data Plane Setup Guide - Comparison and Enhancements

**Date**: January 22, 2026  
**Purpose**: Document differences between the two Data Plane setup guides and recommended enhancements

---

## Guides Comparison

### Guide 1: workshop-tibco-platform/docs/howto/how-to-dp-aks-setup-guide.md
**Source**: Existing reference guide  
**Focus**: Step-by-step technical implementation using TIBCO scripts

**Strengths**:
- Docker container option for consistent CLI environment
- Detailed Azure networking (NAT Gateway, API Server VNet integration)
- Workload Identity setup for cert-manager and external-dns
- ClusterIssuer with Azure DNS integration via cert-manager
- Detailed observability setup (Elastic ECK 8.17.3, Prometheus 48.3.4)
- Actual SaaS CP registration workflow with specific helm commands
- Uses TIBCO's pre-built scripts (pre-aks-cluster-script.sh, aks-cluster-create.sh, post-aks-cluster-script.sh)

### Guide 2: workshop-tp-aks/howto/how-to-dp-aks-setup-guide.md
**Source**: Newly created guide  
**Focus**: Comprehensive end-to-end guide with explanations

**Strengths**:
- More beginner-friendly with detailed explanations
- Architecture diagrams (Mermaid)
- Emphasis on DNS-based communication (no VNet peering needed)
- Comprehensive troubleshooting section
- Step-by-step Azure resource creation
- Manual approach (doesn't require TIBCO scripts)
- Detailed verification steps

---

## Recommended Enhancements to New Guide

### 1. Add Docker Container Option (High Priority)

Add section in Part 1 (Environment Preparation):

```markdown
### Step 1.1b: Using Docker Container for CLI Tools (Optional)

For a consistent environment across different systems:

**Build Docker Image**:
```bash
# From tp-helm-charts/docs/workshop directory
docker buildx build --platform="linux/amd64" --progress=plain -t workshop-cli-tools:latest --load .
```

**Run Container**:
```bash
# With workspace volume mount
docker run -it --rm -v $(pwd):/workspace workshop-cli-tools:latest /bin/bash

# All subsequent commands can run inside this container
```
```

### 2. Add Workload Identity Setup (High Priority)

Enhance Part 2 (AKS Cluster Setup) with:

```markdown
### Step 2.6: Configure Workload Identity

**Enable Workload Identity on cluster**:
```bash
# Already enabled during cluster creation with --enable-managed-identity
# Verify it's enabled:
az aks show --resource-group "$AZURE_RESOURCE_GROUP" --name "$AKS_CLUSTER_NAME" --query "securityProfile.workloadIdentity"
```

**Create Federated Identity for cert-manager**:
```bash
export TP_CLIENT_ID=$(az aks show --resource-group "$AZURE_RESOURCE_GROUP" --name "$AKS_CLUSTER_NAME" --query "identityProfile.kubeletidentity.clientId" -o tsv)

# Setup will be done in Part 4 with cert-manager installation
```
```

### 3. Enhance ClusterIssuer Configuration (Medium Priority)

Update Part 7 (Certificate Management) to include Azure DNS integration:

```markdown
### Option C: ClusterIssuer with Azure DNS (Recommended for Production)

**Install cert-manager with Workload Identity**:
```bash
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n cert-manager cert-manager cert-manager \
  --repo "https://charts.jetstack.io" --version "v1.17.1" -f - <<EOF
installCRDs: true
podLabels:
  azure.workload.identity/use: "true"
serviceAccount:
  labels:
    azure.workload.identity/use: "true"
EOF
```

**Create ClusterIssuer with Azure DNS01 challenge**:
```bash
export TP_CLIENT_ID=$(az aks show --resource-group "$AZURE_RESOURCE_GROUP" --name "$AKS_CLUSTER_NAME" --query "identityProfile.kubeletidentity.clientId" -o tsv)

kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod-azure-dns
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: admin@example.com
    privateKeySecretRef:
      name: letsencrypt-prod-azure-dns
    solvers:
    - dns01:
        azureDNS:
          subscriptionID: "$AZURE_SUBSCRIPTION_ID"
          resourceGroupName: "$AZURE_RESOURCE_GROUP"
          hostedZoneName: "$TP_DP_DOMAIN"
          managedIdentity:
            clientID: "$TP_CLIENT_ID"
EOF
```

This approach uses Azure DNS01 challenge (more reliable than HTTP01 for wildcard certs).
```

### 4. Add SaaS CP Registration Details (High Priority)

Enhance Part 6 (Data Plane Registration) with actual workflow:

```markdown
### Step 6.4: Execute Registration Helm Commands

The Control Plane will provide helm commands. Example workflow:

**Add Helm Repo**:
```bash
helm repo add tibco-platform-public https://tibcosoftware.github.io/tp-helm-charts
helm repo update tibco-platform-public
```

**Create and Label Namespace**:
```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: $TP_DP_NAMESPACE
  labels:
    platform.tibco.com/dataplane-id: "<your-dataplane-id>"
EOF
```

**Configure Namespace**:
```bash
helm upgrade --install -n $TP_DP_NAMESPACE dp-configure-namespace tibco-platform-public/dp-configure-namespace \
  --version x.x.x \
  --set global.tibco.dataPlaneId=<your-dataplane-id> \
  --set global.tibco.subscriptionId=<your-subscription-id> \
  --set global.tibco.primaryNamespaceName=$TP_DP_NAMESPACE \
  --set global.tibco.serviceAccount=sa \
  --set global.tibco.containerRegistry.url=$CONTAINER_REGISTRY_SERVER \
  --set global.tibco.containerRegistry.username=$CONTAINER_REGISTRY_USERNAME \
  --set global.tibco.containerRegistry.password=$CONTAINER_REGISTRY_PASSWORD \
  --set global.tibco.containerRegistry.repository=tibco-platform-docker-prod \
  --set global.tibco.enableClusterScopedPerm=true \
  --set networkPolicy.createDeprecatedPolicies=false
```

**Deploy Core Infrastructure**:
```bash
helm upgrade --install dp-core-infrastructure -n $TP_DP_NAMESPACE tibco-platform-public/dp-core-infrastructure \
  --version x.x.x \
  --set global.tibco.dataPlaneId=<your-dataplane-id> \
  --set global.tibco.subscriptionId=<your-subscription-id> \
  --set tp-tibtunnel.configure.accessKey=<your-access-key> \
  --set tp-tibtunnel.connect.url=<your-tibtunnel-url> \
  --set global.tibco.serviceAccount=sa \
  --set global.tibco.containerRegistry.url=$CONTAINER_REGISTRY_SERVER \
  --set global.tibco.containerRegistry.repository=tibco-platform-docker-prod \
  --set global.proxy.noProxy='' \
  --set global.logging.fluentbit.enabled=true
```
```

### 5. Reference to Observability Guide (Low Priority)

Add note in Part 9 about observability setup:

```markdown
### Step 9.7: Set Up Observability (Optional)

For production deployments, set up observability stack:

See [how-to-dp-aks-observability.md](how-to-dp-aks-observability.md) for:
- Elastic Stack (Elasticsearch, Kibana, APM)
- Prometheus and Grafana
- Integration with TIBCO Platform
```

---

## Key Differences in Approach

| Aspect | Existing Guide | New Guide |
|--------|---------------|-----------|
| **Script Dependency** | Uses TIBCO pre-built scripts | Manual Azure CLI commands |
| **Networking** | Advanced (NAT Gateway, API Server VNet) | Standard (Kubenet or Azure CNI) |
| **Identity** | Workload Identity for cert-manager/external-dns | Managed Identity |
| **Certificates** | ClusterIssuer with Azure DNS01 | Self-signed or Let's Encrypt HTTP01 |
| **Target Audience** | TIBCO implementation teams | General DevOps engineers |
| **Documentation Style** | Script-focused, concise | Explanatory, comprehensive |

---

## Recommendations

### For workshop-tp-aks Guide:

**Must Add**:
1. ✅ Docker container option (consistency)
2. ✅ Workload Identity setup (security best practice)
3. ✅ Actual SaaS CP registration workflow (practical)

**Should Add**:
4. ClusterIssuer with Azure DNS01 (better than HTTP01 for wildcards)
5. Reference to TIBCO scripts as alternative approach

**Nice to Have**:
6. Advanced networking section (NAT Gateway) for production
7. API Server VNet integration option

### Implementation Priority:

**Phase 1** (Do Now):
- Add SaaS CP registration workflow with actual helm commands
- Add reference to observability guide placeholder

**Phase 2** (After creating observability guide):
- Cross-reference between all three guides
- Create quick start vs detailed setup matrix

**Phase 3** (Future):
- Add advanced networking options
- Add production hardening checklist
- Add cost optimization section

---

## Action Items

- [ ] Update new DP guide with SaaS registration workflow
- [ ] Create observability guide (in progress)
- [ ] Add cross-references between guides
- [ ] Document script-based vs manual approach trade-offs
- [ ] Add decision tree: "Which guide should I use?"

---

**Notes**:
- Both guides are valid for different audiences
- New guide is more beginner-friendly
- Existing guide is more production-ready with advanced features
- Consider creating a "Quick Start" vs "Production Setup" version split
