You are helping deploy TIBCO Platform Control Plane **and** Data Plane on Azure Kubernetes Service (AKS). This skill assumes Control Plane is already installed (via `tibco-provision-cp`) and adds the Data Plane components to the same cluster.

## Before You Start

Verify Control Plane is healthy:
```bash
kubectl get pods -n ${CP_INSTANCE_ID}-ns
helm list -n ${CP_INSTANCE_ID}-ns
```

Confirm environment values:
```bash
echo "CP_INSTANCE_ID=${CP_INSTANCE_ID}"
echo "DP_INSTANCE_ID=${DP_INSTANCE_ID}"
echo "TP_BASE_DNS_DOMAIN=${TP_BASE_DNS_DOMAIN}"
echo "TP_CONTAINER_REGISTRY_URL=${TP_CONTAINER_REGISTRY_URL}"
```

Identify the ingress class in use:
```bash
kubectl get ingressclass
INGRESS_CLASS=$(kubectl get ingressclass -o jsonpath='{.items[0].metadata.name}')
echo "Ingress class: ${INGRESS_CLASS}"
```

## Step 1 — Create Data Plane Namespace

```bash
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${DP_INSTANCE_ID}-ns
  labels:
    platform.tibco.com/dataplane-id: ${DP_INSTANCE_ID}
    platform.tibco.com/controlplane-instance-id: ${CP_INSTANCE_ID}
EOF

kubectl create serviceaccount ${DP_INSTANCE_ID}-sa -n ${DP_INSTANCE_ID}-ns 2>/dev/null || echo "SA already exists"
```

## Step 2 — Create Image Pull Secret in DP Namespace

```bash
kubectl create secret docker-registry tibco-container-registry-credentials \
  --docker-server="${TP_CONTAINER_REGISTRY_URL}" \
  --docker-username="${TP_CONTAINER_REGISTRY_USER}" \
  --docker-password="${TP_CONTAINER_REGISTRY_PASSWORD}" \
  --docker-email="platform@company.com" \
  -n ${DP_INSTANCE_ID}-ns \
  --dry-run=client -o yaml | kubectl apply -f -
```

If using Azure Container Registry (ACR) as a private registry, it is attached at the cluster level (done in prerequisites) so no separate pull secret is needed.

## Step 3 — Install dp-configure-namespace

```bash
helm upgrade --install --wait --timeout 10m \
  --create-namespace -n ${DP_INSTANCE_ID}-ns \
  ${DP_INSTANCE_ID}-dp-configure-namespace tibco-platform-public/dp-configure-namespace \
  --set "global.tibco.dataPlane.id=${DP_INSTANCE_ID}" \
  --set "global.tibco.dataPlane.namespace=${DP_INSTANCE_ID}-ns" \
  --set "global.tibco.controlPlane.instanceId=${CP_INSTANCE_ID}" \
  --set "global.tibco.containerRegistry.url=${TP_CONTAINER_REGISTRY_URL}" \
  --set "global.tibco.containerRegistry.username=${TP_CONTAINER_REGISTRY_USER}" \
  --set "global.tibco.containerRegistry.password=${TP_CONTAINER_REGISTRY_PASSWORD}" \
  --set "global.tibco.serviceAccount=${DP_INSTANCE_ID}-sa" \
  --set "global.tibco.createNetworkPolicy=false" \
  --set "global.imagePullSecrets[0].name=tibco-container-registry-credentials"
```

Verify:
```bash
kubectl get pods -n ${DP_INSTANCE_ID}-ns
kubectl get configmap -n ${DP_INSTANCE_ID}-ns
```

## Step 4 — Install dp-config-aks

The `dp-config-aks` chart installs AKS-specific Data Plane infrastructure (storage classes, ingress config, cert-manager issuers):

```bash
helm upgrade --install --wait --timeout 20m \
  -n ${DP_INSTANCE_ID}-ns \
  ${DP_INSTANCE_ID}-dp-config-aks tibco-platform-public/dp-config-aks \
  --set "global.tibco.dataPlane.id=${DP_INSTANCE_ID}" \
  --set "global.tibco.dataPlane.namespace=${DP_INSTANCE_ID}-ns" \
  --set "global.tibco.controlPlane.instanceId=${CP_INSTANCE_ID}" \
  --set "global.tibco.createNetworkPolicy=false" \
  --set "global.tibco.containerRegistry.url=${TP_CONTAINER_REGISTRY_URL}" \
  --set "global.tibco.containerRegistry.username=${TP_CONTAINER_REGISTRY_USER}" \
  --set "global.tibco.containerRegistry.password=${TP_CONTAINER_REGISTRY_PASSWORD}" \
  --set "global.imagePullSecrets[0].name=tibco-container-registry-credentials" \
  --set "ingress.className=${INGRESS_CLASS}" \
  --set "ingress.annotations.cert-manager\\.io/cluster-issuer=letsencrypt-prod"
```

## Step 5 — Install dp-core-infrastructure

```bash
helm upgrade --install --wait --timeout 20m \
  -n ${DP_INSTANCE_ID}-ns \
  ${DP_INSTANCE_ID}-dp-core-infrastructure tibco-platform-public/dp-core-infrastructure \
  --set "global.tibco.dataPlane.id=${DP_INSTANCE_ID}" \
  --set "global.tibco.dataPlane.namespace=${DP_INSTANCE_ID}-ns" \
  --set "global.tibco.controlPlane.instanceId=${CP_INSTANCE_ID}" \
  --set "global.tibco.controlPlane.host=https://admin.${CP_INSTANCE_ID}-my.${TP_BASE_DNS_DOMAIN}" \
  --set "global.tibco.containerRegistry.url=${TP_CONTAINER_REGISTRY_URL}" \
  --set "global.tibco.containerRegistry.username=${TP_CONTAINER_REGISTRY_USER}" \
  --set "global.tibco.containerRegistry.password=${TP_CONTAINER_REGISTRY_PASSWORD}" \
  --set "global.tibco.serviceAccount=${DP_INSTANCE_ID}-sa" \
  --set "global.tibco.createNetworkPolicy=false" \
  --set "global.imagePullSecrets[0].name=tibco-container-registry-credentials" \
  --set "global.tibco.dataPlane.dnsDomain=${DP_INSTANCE_ID}.${TP_BASE_DNS_DOMAIN}" \
  --set "ingress.className=${INGRESS_CLASS}" \
  --set "ingress.annotations.cert-manager\\.io/cluster-issuer=letsencrypt-prod"
```

Monitor:
```bash
kubectl get pods -n ${DP_INSTANCE_ID}-ns -w
```

## Step 6 — DNS Records for Data Plane

If not using external-dns, create Azure DNS records for the Data Plane domain:

```bash
INGRESS_IP=$(kubectl get svc -n ingress-system -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || \
             kubectl get svc -n traefik -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')

az network dns record-set a add-record \
  --resource-group "${AZURE_DNS_RESOURCE_GROUP}" \
  --zone-name "${TP_BASE_DNS_DOMAIN}" \
  --record-set-name "*.${DP_INSTANCE_ID}" \
  --ipv4-address "${INGRESS_IP}"
```

## Step 7 — Register Data Plane in Control Plane

Open the Control Plane admin UI:
```
https://admin.${CP_INSTANCE_ID}-my.${TP_BASE_DNS_DOMAIN}
```

1. Go to **Infrastructure** → **Data Planes** → **Add Data Plane**
2. Fill in:
   - **Name**: `${DP_INSTANCE_ID}`
   - **Namespace**: `${DP_INSTANCE_ID}-ns`
   - **Ingress class**: `${INGRESS_CLASS}`
   - **DNS domain**: `${DP_INSTANCE_ID}.${TP_BASE_DNS_DOMAIN}`

## Step 8 — Verify

```bash
kubectl get pods -n ${DP_INSTANCE_ID}-ns
kubectl get pvc -n ${DP_INSTANCE_ID}-ns
kubectl get ingress -n ${DP_INSTANCE_ID}-ns
kubectl get certificate -n ${DP_INSTANCE_ID}-ns
```

Check DP agent connectivity:
```bash
kubectl logs -n ${DP_INSTANCE_ID}-ns \
  $(kubectl get pods -n ${DP_INSTANCE_ID}-ns -l app=dp-agent -o name | head -1) \
  --tail=50 | grep -E "connected|registered|error" | tail -20
```

## Troubleshooting

**ACR pull authentication**: If pods fail with image pull errors and you are using ACR:
```bash
az aks update --resource-group ${AKS_RESOURCE_GROUP} --name ${AKS_CLUSTER_NAME} \
  --attach-acr $(az acr show --name ${ACR_NAME} --resource-group ${AKS_RESOURCE_GROUP} --query id -o tsv)
```

**Certificate pending**: Check the DNS challenge:
```bash
kubectl describe certificate -n ${DP_INSTANCE_ID}-ns
kubectl get events -n cert-manager | grep ${DP_INSTANCE_ID} | tail -10
```

**DP agent not connecting**: Check `proxyUrl` is set correctly in the DP values pointing to the CP admin host.
