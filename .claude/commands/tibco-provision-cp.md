You are helping deploy the TIBCO Platform Control Plane on Azure Kubernetes Service (AKS). Follow these steps in order, running each command and verifying the output before continuing.

## Before You Start

Confirm that `tibco-prerequisites` has passed. Then confirm these values are set:

```bash
echo "CP_INSTANCE_ID=${CP_INSTANCE_ID}"
echo "TP_BASE_DNS_DOMAIN=${TP_BASE_DNS_DOMAIN}"
echo "TP_CONTAINER_REGISTRY_URL=${TP_CONTAINER_REGISTRY_URL}"
echo "CP_DB_HOST=${CP_DB_HOST}"
```

Check the latest available `tibco-cp-base` chart version:
```bash
helm search repo tibco-platform-public/tibco-cp-base --versions | head -5
```

## Step 1 — Verify Pre-Installed Components

Confirm cert-manager, ingress controller, and storage classes are in place:

```bash
kubectl get pods -n cert-manager
kubectl get pods -n ingress-system 2>/dev/null || kubectl get pods -n traefik 2>/dev/null
kubectl get storageclass | grep -E "azure|managed"
```

If any component is missing, run `tibco-prerequisites` first.

## Step 2 — Metrics Server

Ensure metrics-server is running (required for HPA):

```bash
kubectl get deployment -n kube-system metrics-server 2>/dev/null && echo "metrics-server OK" || \
  helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/ && \
  helm repo update && \
  helm upgrade --install --wait --timeout 5m -n kube-system metrics-server metrics-server/metrics-server
```

## Step 3 — Get Ingress External IP

Get the ingress controller LoadBalancer IP. This is needed for DNS configuration:

```bash
INGRESS_IP=$(kubectl get svc -n ingress-system -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || \
             kubectl get svc -n traefik -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
echo "Ingress External IP: ${INGRESS_IP}"
```

If using Azure DNS with external-dns, it will automatically create A records. If managing DNS manually, note this IP and create wildcard records:
- `*.${CP_INSTANCE_ID}-my.${TP_BASE_DNS_DOMAIN}` → `${INGRESS_IP}`
- `*.${CP_INSTANCE_ID}-tunnel.${TP_BASE_DNS_DOMAIN}` → `${INGRESS_IP}`

## Step 4 — TLS Certificate

Determine the ingress class in use:

```bash
kubectl get ingressclass
```

Common options: `traefik`, `nginx`. Note it as `INGRESS_CLASS`.

For cert-manager with Let's Encrypt, create a ClusterIssuer if it doesn't exist:

```bash
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: platform@company.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: ${INGRESS_CLASS}
EOF
```

## Step 5 — Prepare Helm Values

Generate the `tibco-cp-base` values file:

```bash
cat > /tmp/tibco-cp-values.yaml << EOF
global:
  tibco:
    containerRegistry:
      url: ${TP_CONTAINER_REGISTRY_URL}
      username: ${TP_CONTAINER_REGISTRY_USER}
      password: ${TP_CONTAINER_REGISTRY_PASSWORD}
    serviceAccount: ${CP_INSTANCE_ID}-sa
    createNetworkPolicy: false
    enableLogging: true
  imagePullSecrets:
    - name: tibco-container-registry-credentials
  certificates:
    secretName: ""

tibco:
  controlPlane:
    baseConfig:
      cpInstanceId: ${CP_INSTANCE_ID}
      cpNamespace: ${CP_INSTANCE_ID}-ns
      serviceAccount: ${CP_INSTANCE_ID}-sa
    dnsConfig:
      baseDnsDomain: ${TP_BASE_DNS_DOMAIN}
    database:
      dbHost: ${CP_DB_HOST}
      dbPort: "5432"
      dbName: "${CP_INSTANCE_ID}postgres"
      secretRef: ${CP_INSTANCE_ID}-provider-cp-database
    sessionConfig:
      sessionKeysSecretRef: session-keys
    encryptionConfig:
      encryptionSecretRef: cporch-encryption-secret
    ingress:
      className: "${INGRESS_CLASS:-traefik}"
      annotations:
        cert-manager.io/cluster-issuer: letsencrypt-prod
EOF
```

Review the values:
```bash
cat /tmp/tibco-cp-values.yaml
```

Ask the user to confirm before proceeding.

## Step 6 — Install TIBCO Control Plane

```bash
helm upgrade --install --wait --timeout 60m \
  --create-namespace -n ${CP_INSTANCE_ID}-ns \
  ${CP_INSTANCE_ID}-tibco-cp tibco-platform-public/tibco-cp-base \
  -f /tmp/tibco-cp-values.yaml
```

This takes 10-20 minutes. Monitor in parallel:

```bash
kubectl get pods -n ${CP_INSTANCE_ID}-ns -w
```

## Step 7 — Verify Deployment

Check all pods are Running:

```bash
kubectl get pods -n ${CP_INSTANCE_ID}-ns
kubectl get pvc -n ${CP_INSTANCE_ID}-ns
kubectl get ingress -n ${CP_INSTANCE_ID}-ns
```

Check for any problem pods:
```bash
kubectl get pods -n ${CP_INSTANCE_ID}-ns \
  --field-selector='status.phase!=Running,status.phase!=Succeeded'
```

Describe failing pods if any:
```bash
kubectl describe pod -n ${CP_INSTANCE_ID}-ns <pod-name>
kubectl logs -n ${CP_INSTANCE_ID}-ns <pod-name> --previous 2>/dev/null || \
kubectl logs -n ${CP_INSTANCE_ID}-ns <pod-name>
```

## Step 8 — Verify DNS and TLS

Check that the ingress has an address:
```bash
kubectl get ingress -n ${CP_INSTANCE_ID}-ns -o wide
```

Verify DNS resolution for the Control Plane admin URL:
```bash
nslookup admin.${CP_INSTANCE_ID}-my.${TP_BASE_DNS_DOMAIN} 2>/dev/null || \
  dig +short admin.${CP_INSTANCE_ID}-my.${TP_BASE_DNS_DOMAIN}
```

Check certificate status:
```bash
kubectl get certificate -n ${CP_INSTANCE_ID}-ns
kubectl get certificaterequest -n ${CP_INSTANCE_ID}-ns
```

## Step 9 — Access the Control Plane

The admin URL:
```
https://admin.${CP_INSTANCE_ID}-my.${TP_BASE_DNS_DOMAIN}
```

Get the initial admin credentials:
```bash
kubectl get secret -n ${CP_INSTANCE_ID}-ns | grep -i admin
kubectl get secret -n ${CP_INSTANCE_ID}-ns tibco-cp-admin-secret \
  -o jsonpath='{.data.password}' 2>/dev/null | base64 -d && echo
```

Report the admin URL and credentials to the user.

## Troubleshooting

**Image pull errors**: Check ACR attachment and pull secret:
```bash
az aks show --resource-group ${AKS_RESOURCE_GROUP} --name ${AKS_CLUSTER_NAME} \
  --query acrProfile -o table
kubectl get secret tibco-container-registry-credentials -n ${CP_INSTANCE_ID}-ns
```

**Certificate not issued**: Check the ACME challenge:
```bash
kubectl describe certificaterequest -n ${CP_INSTANCE_ID}-ns
kubectl get events -n cert-manager | grep -i error | tail -10
```

**Ingress no address**: Check the ingress controller is running and has an external IP:
```bash
kubectl get svc -A | grep LoadBalancer
```
