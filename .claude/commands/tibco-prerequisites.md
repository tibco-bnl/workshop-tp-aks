You are helping validate and set up all prerequisites for a TIBCO Platform deployment on Azure Kubernetes Service (AKS). Work through each phase methodically — run each check, report the result, and fix gaps before moving on.

## Reference
Read `howto/prerequisites-checklist-for-customer.md` for the full requirements list. This skill focuses on the technical setup required before running `tibco-provision-cp` or `tibco-provision-cp-dp`.

## Phase 1 — Cluster Access

Verify `kubectl` and Azure CLI access:

```bash
kubectl version --short
kubectl get nodes -o wide
az account show --query '{subscription:id, name:name}' -o table
az aks show --resource-group "${AKS_RESOURCE_GROUP}" --name "${AKS_CLUSTER_NAME}" \
  --query '{name:name, version:kubernetesVersion, state:provisioningState}' -o table 2>/dev/null || \
  echo "AKS_RESOURCE_GROUP or AKS_CLUSTER_NAME not set — please provide these values"
```

Report: kubectl server version, number of Ready nodes, Azure subscription, and cluster state.

## Phase 2 — Collect Configuration

Ask the user to confirm or provide these values (check `scripts/env.sh` or `howto/v1.18/how-to-cp-and-dp-aks-setup-guide.md` for defaults):

| Variable | Description | Example |
|----------|-------------|---------|
| `CP_INSTANCE_ID` | Control Plane ID, max 5 chars, **no hyphens** | `cp1` |
| `DP_INSTANCE_ID` | Data Plane ID | `dp1` |
| `AKS_RESOURCE_GROUP` | Azure resource group | `rg-tibco-workshop` |
| `AKS_CLUSTER_NAME` | AKS cluster name | `aks-tibco-workshop` |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID | `a1b2c3d4-...` |
| `AZURE_DNS_RESOURCE_GROUP` | Resource group for Azure DNS zone | `rg-dns` |
| `TP_BASE_DNS_DOMAIN` | Base DNS domain | `aks.example.com` |
| `TP_CONTAINER_REGISTRY_URL` | TIBCO JFrog registry | `csgprduswrepoedge.jfrog.io` |
| `TP_CONTAINER_REGISTRY_USER` | JFrog username | |
| `TP_CONTAINER_REGISTRY_PASSWORD` | JFrog password | |
| `CP_DB_HOST` | PostgreSQL hostname | |
| `CP_DB_USERNAME` | PostgreSQL username | |
| `CP_DB_PASSWORD` | PostgreSQL password | |
| `ACR_NAME` | Azure Container Registry name (if using private registry) | `tibcoworkshopacr` |

Export all provided values and use them in subsequent steps.

## Phase 3 — Storage Classes

Check that Azure Disk (RWO) and Azure Files (RWX) storage classes are present:

```bash
kubectl get storageclass
```

Required:
- `azure-disk` or `managed-premium` — block storage, used by PostgreSQL, EMS
- `azure-file` or `azurefile-csi` — file storage with RWX, used by CP shared logs and BWCE artifacts

If missing, install via `dp-config-aks`:
```bash
helm repo add tibco-platform-public https://tibcosoftware.github.io/tp-helm-charts
helm repo update
helm upgrade --install --wait --timeout 1h --create-namespace \
  -n storage-system dp-config-aks-storage tibco-platform-public/dp-config-aks \
  --set "global.tibco.createNetworkPolicy=false"
```

## Phase 4 — Ingress Controller

Check if cert-manager and an ingress controller are deployed:

```bash
helm list -A | grep -E "cert-manager|traefik|nginx|ingress"
kubectl get pods -n cert-manager 2>/dev/null | head -5
kubectl get pods -n ingress-system 2>/dev/null | head -5
```

If cert-manager is missing:
```bash
helm repo add jetstack https://charts.jetstack.io && helm repo update
helm upgrade --install --wait --timeout 10m --create-namespace -n cert-manager cert-manager \
  jetstack/cert-manager --set installCRDs=true
```

If Traefik (recommended for AKS) is missing:
```bash
helm repo add traefik https://traefik.github.io/charts && helm repo update
helm upgrade --install --wait --timeout 10m --create-namespace -n ingress-system traefik \
  traefik/traefik \
  --set "service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-health-probe-request-path=/ping"
```

Get the external IP of the ingress controller:
```bash
kubectl get svc -n ingress-system -o wide
```

## Phase 5 — Control Plane Namespace and Service Account

Create the CP namespace with required labels:

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${CP_INSTANCE_ID}-ns
  labels:
    platform.tibco.com/controlplane-instance-id: ${CP_INSTANCE_ID}
EOF

kubectl create serviceaccount ${CP_INSTANCE_ID}-sa -n ${CP_INSTANCE_ID}-ns 2>/dev/null || echo "SA already exists"
```

## Phase 6 — Container Registry Access

Test JFrog registry credentials:

```bash
curl -u "${TP_CONTAINER_REGISTRY_USER}:${TP_CONTAINER_REGISTRY_PASSWORD}" \
  -s -o /dev/null -w "%{http_code}" \
  "https://${TP_CONTAINER_REGISTRY_URL}/v2/_catalog"
```

HTTP 200 = credentials valid.

Create image pull secret:

```bash
kubectl create secret docker-registry tibco-container-registry-credentials \
  --docker-server="${TP_CONTAINER_REGISTRY_URL}" \
  --docker-username="${TP_CONTAINER_REGISTRY_USER}" \
  --docker-password="${TP_CONTAINER_REGISTRY_PASSWORD}" \
  --docker-email="platform@company.com" \
  -n ${CP_INSTANCE_ID}-ns \
  --dry-run=client -o yaml | kubectl apply -f -
```

If using ACR as a private registry, attach it to the AKS cluster:
```bash
ACR_ID=$(az acr show --name ${ACR_NAME} --resource-group ${AKS_RESOURCE_GROUP} --query id -o tsv)
az aks update --resource-group ${AKS_RESOURCE_GROUP} --name ${AKS_CLUSTER_NAME} --attach-acr "${ACR_ID}"
```

## Phase 7 — Kubernetes Secrets

Generate and create required secrets:

```bash
# Session keys
TSC_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)
DOMAIN_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)
kubectl create secret generic session-keys -n ${CP_INSTANCE_ID}-ns \
  --from-literal=TSC_SESSION_KEY=${TSC_SESSION_KEY} \
  --from-literal=DOMAIN_SESSION_KEY=${DOMAIN_SESSION_KEY} \
  --dry-run=client -o yaml | kubectl apply -f -

# Encryption secret
CP_ENCRYPTION_SECRET=$(openssl rand -base64 32)
kubectl create secret generic cporch-encryption-secret -n ${CP_INSTANCE_ID}-ns \
  --from-literal=ENCRYPTION_KEY=${CP_ENCRYPTION_SECRET} \
  --dry-run=client -o yaml | kubectl apply -f -

# Database credentials
kubectl create secret generic ${CP_INSTANCE_ID}-provider-cp-database -n ${CP_INSTANCE_ID}-ns \
  --from-literal=db_username="${CP_DB_USERNAME}" \
  --from-literal=db_password="${CP_DB_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -
```

## Phase 8 — DNS Zone

Verify the Azure DNS zone exists and records can be created:

```bash
az network dns zone show \
  --resource-group "${AZURE_DNS_RESOURCE_GROUP}" \
  --name "${TP_BASE_DNS_DOMAIN}" \
  --query '{name:name, nameServers:nameServers}' -o table
```

If external-dns is being used, verify it is running:
```bash
kubectl get pods -n external-dns-system 2>/dev/null || echo "external-dns not found — DNS records will be created manually"
```

## Phase 9 — Helm Repository

```bash
helm repo add tibco-platform-public https://tibcosoftware.github.io/tp-helm-charts
helm repo update
helm search repo tibco-platform-public/tibco-cp-base --versions | head -5
```

## Phase 10 — Final Summary

```bash
echo "=== Namespace ===" && kubectl get namespace ${CP_INSTANCE_ID}-ns
echo "=== Service Account ===" && kubectl get sa ${CP_INSTANCE_ID}-sa -n ${CP_INSTANCE_ID}-ns
echo "=== Secrets ===" && kubectl get secrets -n ${CP_INSTANCE_ID}-ns | grep -E "registry|session|encryption|database"
echo "=== Storage Classes ===" && kubectl get storageclass | grep -E "azure|managed"
echo "=== Ingress Controller ===" && kubectl get svc -n ingress-system -o wide 2>/dev/null || kubectl get svc -A | grep LoadBalancer
echo "=== cert-manager ===" && kubectl get pods -n cert-manager
echo "=== Helm Repo ===" && helm repo list | grep tibco
```

Report a PASS/FAIL per item. If everything passes, the environment is ready for `tibco-provision-cp`.
