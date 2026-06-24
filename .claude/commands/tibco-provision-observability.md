You are helping deploy the TIBCO Platform observability stack on Azure Kubernetes Service (AKS). This installs Elasticsearch/Kibana (via ECK operator) and Prometheus/Grafana (via kube-prometheus-stack) for logs, metrics, and traces.

## Before You Start

Verify Data Plane is deployed:
```bash
kubectl get pods -n ${DP_INSTANCE_ID}-ns
helm list -n ${DP_INSTANCE_ID}-ns
```

Confirm environment values:
```bash
echo "DP_INSTANCE_ID=${DP_INSTANCE_ID}"
echo "TP_BASE_DNS_DOMAIN=${TP_BASE_DNS_DOMAIN}"
echo "TP_CONTAINER_REGISTRY_URL=${TP_CONTAINER_REGISTRY_URL}"
INGRESS_CLASS=$(kubectl get ingressclass -o jsonpath='{.items[0].metadata.name}')
echo "Ingress class: ${INGRESS_CLASS}"
```

## Step 1 — Create Observability Namespaces

```bash
for ns in elastic-system prometheus-system; do
  kubectl create namespace ${ns} --dry-run=client -o yaml | kubectl apply -f -
done
```

## Step 2 — ECK Operator

```bash
helm repo add elastic https://helm.elastic.co && helm repo update

helm upgrade --install --wait --timeout 10m \
  --create-namespace -n elastic-system eck-operator elastic/eck-operator \
  --set managedNamespaces="{${DP_INSTANCE_ID}-ns}" \
  --set installCRDs=true
```

Verify:
```bash
kubectl get pods -n elastic-system
kubectl get crd | grep elastic
```

## Step 3 — dp-config-es (Elasticsearch + Kibana)

Install the TIBCO Data Plane Elasticsearch chart:

```bash
helm upgrade --install --wait --timeout 30m \
  -n ${DP_INSTANCE_ID}-ns \
  ${DP_INSTANCE_ID}-dp-config-es tibco-platform-public/dp-config-es \
  --set "global.tibco.dataPlane.id=${DP_INSTANCE_ID}" \
  --set "global.tibco.dataPlane.namespace=${DP_INSTANCE_ID}-ns" \
  --set "global.tibco.containerRegistry.url=${TP_CONTAINER_REGISTRY_URL}" \
  --set "global.tibco.containerRegistry.username=${TP_CONTAINER_REGISTRY_USER}" \
  --set "global.tibco.containerRegistry.password=${TP_CONTAINER_REGISTRY_PASSWORD}" \
  --set "global.tibco.createNetworkPolicy=false" \
  --set "global.imagePullSecrets[0].name=tibco-container-registry-credentials" \
  --set "dp-config-es.elasticsearch.enabled=true" \
  --set "dp-config-es.kibana.enabled=true" \
  --set "dp-config-es.elasticsearch.storageClass=azurefile-csi" \
  --set "dp-config-es.elasticsearch.storage=20Gi" \
  --set "dp-config-es.ingress.className=${INGRESS_CLASS}" \
  --set "dp-config-es.ingress.annotations.cert-manager\\.io/cluster-issuer=letsencrypt-prod"
```

Monitor Elasticsearch cluster startup (3-5 minutes):
```bash
kubectl get elasticsearch -n ${DP_INSTANCE_ID}-ns -w
```

Wait for `HEALTH=green` and `PHASE=Ready`.

## Step 4 — kube-prometheus-stack

```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts && helm repo update

helm upgrade --install --wait --timeout 30m \
  --create-namespace -n prometheus-system kube-prometheus-stack \
  prometheus-community/kube-prometheus-stack \
  --set "alertmanager.enabled=true" \
  --set "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.storageClassName=azurefile-csi" \
  --set "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage=20Gi" \
  --set "grafana.persistence.enabled=true" \
  --set "grafana.persistence.storageClassName=azurefile-csi" \
  --set "grafana.persistence.size=5Gi" \
  --set "grafana.ingress.enabled=true" \
  --set "grafana.ingress.ingressClassName=${INGRESS_CLASS}" \
  --set "grafana.ingress.hosts[0]=grafana.${DP_INSTANCE_ID}.${TP_BASE_DNS_DOMAIN}" \
  --set "grafana.ingress.annotations.cert-manager\\.io/cluster-issuer=letsencrypt-prod" \
  --set "prometheus.ingress.enabled=true" \
  --set "prometheus.ingress.ingressClassName=${INGRESS_CLASS}" \
  --set "prometheus.ingress.hosts[0]=prometheus.${DP_INSTANCE_ID}.${TP_BASE_DNS_DOMAIN}"
```

Verify:
```bash
kubectl get pods -n prometheus-system
kubectl get svc -n prometheus-system | grep -E "grafana|prometheus"
```

## Step 5 — Prometheus ServiceMonitor for DP

```bash
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: tibco-dp-metrics
  namespace: ${DP_INSTANCE_ID}-ns
  labels:
    release: kube-prometheus-stack
spec:
  namespaceSelector:
    matchNames:
      - ${DP_INSTANCE_ID}-ns
  selector:
    matchLabels:
      platform.tibco.com/dataplane-id: ${DP_INSTANCE_ID}
  endpoints:
    - port: metrics
      interval: 30s
EOF
```

## Step 6 — DNS Records for Observability Endpoints

If not using external-dns, create Azure DNS records:

```bash
INGRESS_IP=$(kubectl get svc -n ingress-system -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || \
             kubectl get svc -n traefik -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')

for subdomain in kibana grafana prometheus; do
  az network dns record-set a add-record \
    --resource-group "${AZURE_DNS_RESOURCE_GROUP}" \
    --zone-name "${TP_BASE_DNS_DOMAIN}" \
    --record-set-name "${subdomain}.${DP_INSTANCE_ID}" \
    --ipv4-address "${INGRESS_IP}" 2>/dev/null || echo "${subdomain}.${DP_INSTANCE_ID} record already exists or using wildcard"
done
```

## Step 7 — Verify All Components

```bash
echo "=== ECK Operator ===" && kubectl get pods -n elastic-system
echo "=== Elasticsearch ===" && kubectl get elasticsearch -n ${DP_INSTANCE_ID}-ns
echo "=== Kibana ===" && kubectl get kibana -n ${DP_INSTANCE_ID}-ns
echo "=== Prometheus ===" && kubectl get pods -n prometheus-system -l app=prometheus
echo "=== Grafana ===" && kubectl get pods -n prometheus-system -l app.kubernetes.io/name=grafana
echo "=== Ingress ===" && kubectl get ingress -n ${DP_INSTANCE_ID}-ns && kubectl get ingress -n prometheus-system
echo "=== Certificates ===" && kubectl get certificate -n ${DP_INSTANCE_ID}-ns && kubectl get certificate -n prometheus-system
```

## Step 8 — Access Dashboards

| Service | URL |
|---------|-----|
| Kibana | `https://kibana.${DP_INSTANCE_ID}.${TP_BASE_DNS_DOMAIN}` |
| Grafana | `https://grafana.${DP_INSTANCE_ID}.${TP_BASE_DNS_DOMAIN}` |
| Prometheus | `https://prometheus.${DP_INSTANCE_ID}.${TP_BASE_DNS_DOMAIN}` |

Get Grafana admin password:
```bash
kubectl get secret -n prometheus-system kube-prometheus-stack-grafana \
  -o jsonpath='{.data.admin-password}' | base64 -d && echo
```

Get Elasticsearch elastic user password:
```bash
ES_SECRET=$(kubectl get elasticsearch -n ${DP_INSTANCE_ID}-ns -o jsonpath='{.items[0].metadata.name}')
kubectl get secret -n ${DP_INSTANCE_ID}-ns ${ES_SECRET}-es-elastic-user \
  -o jsonpath='{.data.elastic}' | base64 -d && echo
```

## Step 9 — Register Observability in Control Plane

In the TIBCO Platform Admin UI → **Data Planes** → select your Data Plane → **Observability**:

1. Add **Elasticsearch** endpoint:
   - URL: `https://kibana.${DP_INSTANCE_ID}.${TP_BASE_DNS_DOMAIN}` (or Elasticsearch internal URL)
   - Username: `elastic`
   - Password: from Step 8
2. Add **Prometheus** endpoint:
   - URL: `http://kube-prometheus-stack-prometheus.prometheus-system:9090`
3. Add **Grafana** endpoint:
   - URL: `https://grafana.${DP_INSTANCE_ID}.${TP_BASE_DNS_DOMAIN}`

## Troubleshooting

**Elasticsearch pods in Init state (AKS)**: Check if the Azure Files storage class supports `ReadWriteMany`:
```bash
kubectl get pvc -n ${DP_INSTANCE_ID}-ns | grep elastic
kubectl describe pvc -n ${DP_INSTANCE_ID}-ns <pvc-name>
```

Ensure `azurefile-csi` is used (not `azure-disk`) for Elasticsearch — disk storage does not support `ReadWriteMany`.

**Grafana not loading dashboards**: Check Prometheus datasource is configured correctly in Grafana admin → Data Sources.
