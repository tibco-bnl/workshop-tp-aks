# Corrections Needed Based on Official TIBCO Sources

## Source References
- Control Plane: https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/docs/workshop/aks/control-plane
- Data Plane: https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/docs/workshop/aks/data-plane
- Cluster Setup: https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/docs/workshop/aks/cluster-setup

## Major Corrections Required

### 1. Control Plane Deployment (how-to-cp-and-dp-aks-setup-guide.md)

#### Current Issues:
- Missing namespace and service account pre-requisites
- Missing required secrets (session-keys, cporch-encryption-secret)
- Incorrect ingress/storage class setup (manual vs using dp-config-aks chart)
- Certificate creation doesn't use cert-manager Certificate CR
- Helm chart values structure doesn't match official format
- Missing DNS records configuration section
- PostgreSQL setup incomplete (missing connection details handling)

#### Required Changes:

**1.1 Add Pre-requisites Section (BEFORE Part 8)**
```bash
## Pre-requisites to create namespace and service account

export CP_INSTANCE_ID="cp1" # unique id (alphanumeric, max 5 chars)

kubectl apply -f <(envsubst '${CP_INSTANCE_ID}' <<'EOF'
apiVersion: v1
kind: Namespace
metadata:
 name: ${CP_INSTANCE_ID}-ns
 labels:
  platform.tibco.com/controlplane-instance-id: ${CP_INSTANCE_ID}
EOF
)

kubectl create serviceaccount ${CP_INSTANCE_ID}-sa -n ${CP_INSTANCE_ID}-ns
```

**1.2 Configure DNS Records and Certificates**
- Need to add section for creating certificates using cert-manager
- Must label ingress-system namespace for network policies
```bash
kubectl label namespace ingress-system networking.platform.tibco.com/non-cp-ns=enable --overwrite=true

kubectl apply -f - << EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: tp-certificate-${CP_INSTANCE_ID}
  namespace: ${CP_INSTANCE_ID}-ns
spec:
  dnsNames:
  - '*.${CP_MY_DNS_DOMAIN}'
  - '*.${CP_TUNNEL_DNS_DOMAIN}'
  issuerRef:
    kind: ClusterIssuer
    name: cic-cert-subscription-scope-production-main
  secretName: tp-certificate-${CP_INSTANCE_ID}
EOF
```

**1.3 Create Required Secrets**
```bash
# Generate and create session-keys secret (REQUIRED)
export TSC_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)
export DOMAIN_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)

kubectl create secret generic session-keys -n ${CP_INSTANCE_ID}-ns \
  --from-literal=TSC_SESSION_KEY=${TSC_SESSION_KEY} \
  --from-literal=DOMAIN_SESSION_KEY=${DOMAIN_SESSION_KEY}

# Generate and create cporch-encryption-secret (REQUIRED)
export CP_ENCRYPTION_SECRET=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c44)

kubectl create secret -n ${CP_INSTANCE_ID}-ns generic cporch-encryption-secret \
  --from-literal=CP_ENCRYPTION_SECRET=${CP_ENCRYPTION_SECRET}
```

**1.4 Ingress and Storage Class Setup**

Current guide uses manual setup. Official source uses `dp-config-aks` helm chart:

```bash
# Install Nginx Ingress Controller
helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ingress-system dp-config-aks-ingress dp-config-aks \
  --labels layer=1 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
clusterIssuer:
  create: false
httpIngress:
  enabled: false
ingress-nginx:
  enabled: true
  controller:
    service:
      type: LoadBalancer
      annotations:
        external-dns.alpha.kubernetes.io/hostname: "*.${TP_DOMAIN}"
        service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /healthz
      enableHttp: false
    config:
      use-forwarded-headers: "true"
      proxy-body-size: "150m"
      proxy-buffer-size: 16k
    extraArgs:
      default-ssl-certificate: ingress-system/tp-certificate-main-ingress
EOF

# Install Storage Classes
helm upgrade --install --wait --timeout 1h --create-namespace \
  -n storage-system dp-config-aks-storage dp-config-aks \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" \
  --labels layer=1 \
  --version "^1.0.0" -f - <<EOF
httpIngress:
  enabled: false
clusterIssuer:
  create: false
storageClass:
  azuredisk:
    enabled: ${TP_DISK_ENABLED}
    name: ${TP_DISK_STORAGE_CLASS}
    volumeBindingMode: Immediate
    reclaimPolicy: "Delete"
    parameters:
      skuName: Premium_LRS
  azurefile:
    enabled: ${TP_FILE_ENABLED}
    name: ${TP_FILE_STORAGE_CLASS}
    volumeBindingMode: Immediate
    reclaimPolicy: "Delete"
    parameters:
      allowBlobPublicAccess: "false"
      skuName: Premium_LRS
EOF
```

**1.5 PostgreSQL Deployment**

Official uses `dp-config-aks` chart to deploy PostgreSQL:

```bash
helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ${CP_INSTANCE_ID}-ns postgres-${CP_INSTANCE_ID} dp-config-aks \
  --labels layer=3 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
global:
  tibco:
    containerRegistry:
      url: "${TP_CONTAINER_REGISTRY_URL}"
      username: "${TP_CONTAINER_REGISTRY_USER}"
      password: "${TP_CONTAINER_REGISTRY_PASSWORD}"
      repository: "${TP_CONTAINER_REGISTRY_REPOSITORY}"
  storageClass: ${TP_DISK_STORAGE_CLASS}
postgresql:
  enabled: true
  auth:
    postgresPassword: postgres
    username: postgres
    password: postgres
    database: "postgres"
  image:
    registry: "${TP_CONTAINER_REGISTRY_URL}"
    repository: ${TP_CONTAINER_REGISTRY_REPOSITORY}/common-postgresql
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
```

**1.6 CP Helm Chart Values**

Official chart values structure:

```yaml
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
router:
  config:
    domainSessionKey:
      secretName: session-keys
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
tp-cp-bootstrap-cronjobs:
  cronjobs:
    setupJob:
      enable: true
router-operator:
  enabled: true
  tscSessionKey:
    secretName: session-keys
    key: TSC_SESSION_KEY
  domainSessionKey:
    secretName: session-keys
    key: DOMAIN_SESSION_KEY
tunproxy:
  tunnelIngress:
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
global:
  tibco:
    createNetworkPolicy: ${TP_ENABLE_NETWORK_POLICY}
    containerRegistry:
      url: "${TP_CONTAINER_REGISTRY_URL}"
      username: "${TP_CONTAINER_REGISTRY_USER}"
      password: "${TP_CONTAINER_REGISTRY_PASSWORD}"
      repository: "tibco-platform-docker-prod"
    controlPlaneInstanceId: "${CP_INSTANCE_ID}"
    serviceAccount: "${CP_INSTANCE_ID}-sa"
  external:
    clusterInfo:
      nodeCIDR: "${TP_VNET_CIDR}"
    db:
      vendor: "postgres"
      host: "postgres-${CP_INSTANCE_ID}-postgresql.${CP_INSTANCE_ID}-ns.svc.cluster.local"
      port: 5432
      sslMode: "disable"
      sslRootCert: ""
      secretName: "postgres-${CP_INSTANCE_ID}-postgresql"
      adminUsername: "postgres"
      adminPasswordKey: "postgres-password"
```

### 2. Data Plane Deployment (how-to-dp-aks-setup-guide.md)

#### Current Issues:
- Missing proper ingress/storage setup using dp-config-aks
- DP namespace configuration not shown
- Missing observability integration (Elastic, Prometheus)
- DP registration procedure from SaaS CP unclear
- Missing capability provisioning details

#### Required Changes:

**2.1 Ingress Controller Setup**

Use dp-config-aks chart:

```bash
helm upgrade --install --wait --timeout 1h --create-namespace \
  -n ingress-system dp-config-aks-ingress dp-config-aks \
  --labels layer=1 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
clusterIssuer:
  create: false
httpIngress:
  enabled: false
ingress-nginx:
  enabled: true
  controller:
    service:
      type: LoadBalancer
      annotations:
        external-dns.alpha.kubernetes.io/hostname: "*.${TP_DOMAIN}"
        service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /healthz
      enableHttp: false
    config:
      use-forwarded-headers: "true"
      proxy-body-size: "150m"
      proxy-buffer-size: 16k
    extraArgs:
      default-ssl-certificate: ingress-system/tp-certificate-main-ingress
EOF
```

**2.2 Storage Classes Setup**

```bash
helm upgrade --install --wait --timeout 1h --create-namespace \
  -n storage-system dp-config-aks-storage dp-config-aks \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" \
  --labels layer=1 \
  --version "^1.0.0" -f - <<EOF
httpIngress:
  enabled: false
clusterIssuer:
  create: false
storageClass:
  azuredisk:
    enabled: ${TP_DISK_ENABLED}
    name: ${TP_DISK_STORAGE_CLASS}
  azurefile:
    enabled: ${TP_FILE_ENABLED}
    name: ${TP_FILE_STORAGE_CLASS}
EOF
```

**2.3 Observability Stack**

Must include Elastic ECK and Prometheus:

```bash
# Install eck-operator
helm upgrade --install --wait --timeout 1h --labels layer=1 --create-namespace \
  -n elastic-system eck-operator eck-operator \
  --repo "https://helm.elastic.co" --version "2.16.0"

# Install dp-config-es
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

# Install Prometheus stack
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
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: ${TP_DISK_STORAGE_CLASS}
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 8Gi
EOF
```

### 3. Common Issues in Both Guides

#### 3.1 Missing Helm Layer Labels
Official guides use `--labels layer=<number>` for dependency tracking

#### 3.2 Missing Container Registry Configuration
Need to add TIBCO container registry setup:

```bash
export TP_CONTAINER_REGISTRY_URL="csgprduswrepoedge.jfrog.io"
export TP_CONTAINER_REGISTRY_USER="<username>"
export TP_CONTAINER_REGISTRY_PASSWORD="<password>"
export TP_CONTAINER_REGISTRY_REPOSITORY="tibco-platform-docker-prod"

kubectl create secret docker-registry tibco-container-registry-credentials \
  --namespace ${CP_INSTANCE_ID}-ns \
  --docker-server=${TP_CONTAINER_REGISTRY_URL} \
  --docker-username=${TP_CONTAINER_REGISTRY_USER} \
  --docker-password=${TP_CONTAINER_REGISTRY_PASSWORD}
```

#### 3.3 Variable Naming Inconsistencies
Official guides use:
- `TP_TIBCO_HELM_CHART_REPO=https://tibcosoftware.github.io/tp-helm-charts`
- `TP_INGRESS_CLASS="nginx"` (or "traefik")
- `TP_DOMAIN` (not separate TP_CP_MY_DOMAIN, TP_DP_MY_DOMAIN)

#### 3.4 Missing Information Needed Section
Should include what information is needed from Control Plane:
- Data Plane ID
- Subscription ID  
- Access Key
- Tibtunnel URL

## Implementation Priority

### Phase 1: Critical Fixes (Required for Functional Deployment)
1. Add namespace and service account creation
2. Add required secrets (session-keys, cporch-encryption-secret)
3. Fix ingress/storage to use dp-config-aks chart
4. Fix PostgreSQL deployment to use dp-config-aks
5. Fix CP helm chart values structure

### Phase 2: Important Enhancements
1. Add cert-manager Certificate CR usage
2. Add observability stack to DP guide
3. Add DP registration procedure details
4. Add capability provisioning examples

### Phase 3: Documentation Quality
1. Align variable naming with official guides
2. Add helm layer labels
3. Add container registry configuration
4. Improve troubleshooting sections with official guidance

## Files to Update

1. `/Users/kul/git/tib/workshop-tp-aks/howto/how-to-cp-and-dp-aks-setup-guide.md`
   - Add Part 8a: Pre-requisites (namespace, serviceaccount)
   - Modify Part 4: Use dp-config-aks for ingress
   - Modify Part 3: Use dp-config-aks for storage
   - Modify Part 5: Use dp-config-aks for PostgreSQL
   - Add Part 7a: Configure DNS and Certificates (cert-manager)
   - Add Part 7b: Create Required Secrets
   - Modify Part 8: Update CP helm values structure

2. `/Users/kul/git/tib/workshop-tp-aks/howto/how-to-dp-aks-setup-guide.md`
   - Modify Part 4: Use dp-config-aks for ingress
   - Modify Part 3: Use dp-config-aks for storage
   - Add Part 5: Install Observability Stack
   - Enhance Part 6: DP Registration with detailed steps
   - Enhance Part 7: DP Deployment with helm values

3. `/Users/kul/git/tib/workshop-tp-aks/scripts/aks-env-variables.sh`
   - Align variable names with official guides
   - Add container registry variables
   - Add CP_INSTANCE_ID variable

## Next Steps

1. Review this corrections document
2. Confirm which corrections to implement
3. Update guides in phases
4. Test updated procedures
5. Update comparison document to reflect changes

---

**Created**: January 22, 2026  
**Based on**: Official TIBCO tp-helm-charts repository (main branch)
