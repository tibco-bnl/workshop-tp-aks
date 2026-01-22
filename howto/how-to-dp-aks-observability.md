# TIBCO Platform Observability Setup on AKS

**Guide for setting up comprehensive monitoring and observability for TIBCO Platform Data Plane on Azure Kubernetes Service**

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Part 1: Elastic Stack Installation](#part-1-elastic-stack-installation)
  - [Step 1.1: Install Elastic ECK Operator](#step-11-install-elastic-eck-operator)
  - [Step 1.2: Deploy Elasticsearch, Kibana, and APM](#step-12-deploy-elasticsearch-kibana-and-apm)
  - [Step 1.3: Verify Elastic Stack Installation](#step-13-verify-elastic-stack-installation)
  - [Step 1.4: Access Kibana Dashboard](#step-14-access-kibana-dashboard)
- [Part 2: Prometheus and Grafana Installation](#part-2-prometheus-and-grafana-installation)
  - [Step 2.1: Install Prometheus Stack](#step-21-install-prometheus-stack)
  - [Step 2.2: Verify Prometheus Installation](#step-22-verify-prometheus-installation)
  - [Step 2.3: Access Grafana Dashboard](#step-23-access-grafana-dashboard)
- [Part 3: OTEL Collectors Configuration](#part-3-otel-collectors-configuration)
  - [Step 3.1: Understanding OTEL Collectors](#step-31-understanding-otel-collectors)
  - [Step 3.2: Configure Trace Collection](#step-32-configure-trace-collection)
  - [Step 3.3: Configure Metrics Collection](#step-33-configure-metrics-collection)
- [Part 4: Integration with TIBCO Platform](#part-4-integration-with-tibco-platform)
  - [Step 4.1: Configure Ingress Trace Collection](#step-41-configure-ingress-trace-collection)
  - [Step 4.2: Configure Application Traces](#step-42-configure-application-traces)
  - [Step 4.3: Configure Service Monitors](#step-43-configure-service-monitors)
- [Part 5: Monitoring Best Practices](#part-5-monitoring-best-practices)
- [Part 6: Troubleshooting](#part-6-troubleshooting)
- [References](#references)

---

## Overview

This guide provides comprehensive instructions for setting up observability for TIBCO Platform Data Plane on Azure Kubernetes Service (AKS). The observability stack includes:

- **Elastic Stack**: 
  - Elasticsearch 8.17.3 (log and trace storage)
  - Kibana 8.17.3 (visualization and analytics)
  - APM Server 8.17.3 (application performance monitoring)

- **Prometheus Stack**:
  - Prometheus 48.3.4 (metrics collection and storage)
  - Grafana (metrics visualization)
  - AlertManager (alerting)

- **OpenTelemetry (OTEL)**:
  - OTEL collectors for traces (Jaeger format)
  - OTEL collectors for metrics
  - Integration with Elastic and Prometheus backends

### Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    TIBCO Platform Applications                   │
│         (BWCE, Flogo, EMS, Control Plane, Data Plane)          │
└────────────┬────────────────────────────────┬───────────────────┘
             │                                │
             │ Traces & Logs                  │ Metrics
             ↓                                ↓
┌────────────────────────┐      ┌─────────────────────────┐
│  OTEL Trace Collector  │      │  OTEL Metrics Collector │
│  (otel-userapp-traces) │      │  (otel-userapp-metrics) │
└────────┬───────────────┘      └────────┬────────────────┘
         │                                │
         │                                │
         ↓                                ↓
┌────────────────────────┐      ┌─────────────────────────┐
│   Elasticsearch        │      │      Prometheus         │
│   + Kibana + APM       │      │      + Grafana          │
└────────────────────────┘      └─────────────────────────┘
```

### Benefits

- **Centralized Logging**: All application and system logs in Elasticsearch
- **Distributed Tracing**: End-to-end request tracing across microservices
- **Metrics Monitoring**: Real-time metrics collection and alerting
- **Performance Analytics**: APM for application performance insights
- **Custom Dashboards**: Pre-built and custom Grafana/Kibana dashboards
- **Alerting**: Prometheus AlertManager for proactive issue detection

---

## Prerequisites

Before proceeding with the observability setup, ensure you have:

### Required Components

- ✅ AKS cluster running and accessible
- ✅ kubectl configured to access the cluster
- ✅ Helm 3.13+ installed
- ✅ Ingress controller installed (Traefik or NGINX)
- ✅ Storage classes available (`azure-disk-sc`)
- ✅ DNS configured for ingress hostnames
- ✅ cert-manager installed (for TLS certificates)

### Environment Variables

Ensure these variables are set:

```bash
# Source the environment variables
source /path/to/aks-env-variables-official.sh

# Verify required variables
echo "TP_TIBCO_HELM_CHART_REPO: ${TP_TIBCO_HELM_CHART_REPO}"
echo "TP_DOMAIN: ${TP_DOMAIN}"
echo "TP_INGRESS_CLASS: ${TP_INGRESS_CLASS}"
echo "TP_DISK_STORAGE_CLASS: ${TP_DISK_STORAGE_CLASS}"
echo "TP_CLUSTER_NAME: ${TP_CLUSTER_NAME}"
echo "DP_NAMESPACE: ${DP_NAMESPACE}"  # If DP is deployed
```

### Resource Requirements

**Elastic Stack**:
- Elasticsearch: 2 CPU, 4Gi memory (minimum)
- Kibana: 1 CPU, 1Gi memory
- APM Server: 250m CPU, 512Mi memory

**Prometheus Stack**:
- Prometheus: 2 CPU, 2Gi memory
- Grafana: 500m CPU, 500Mi memory

**Total**: ~6 CPU cores, 8Gi memory for observability stack

---

## Part 1: Elastic Stack Installation

The Elastic Stack provides log aggregation, search, and distributed tracing capabilities.

### Step 1.1: Install Elastic ECK Operator

The Elastic Cloud on Kubernetes (ECK) operator simplifies deployment and management of Elasticsearch, Kibana, and APM.

```bash
# Install ECK operator
helm upgrade --install --wait --timeout 1h --labels layer=1 \
  --create-namespace -n elastic-system eck-operator eck-operator \
  --repo "https://helm.elastic.co" --version "2.16.0"
```

**Monitor operator installation**:

```bash
# Watch operator pod startup
kubectl get pods -n elastic-system -w

# Expected output:
# NAME                 READY   STATUS    RESTARTS   AGE
# elastic-operator-0   1/1     Running   0          2m

# Verify operator logs
kubectl logs -n elastic-system sts/elastic-operator --tail=50
```

**Expected log messages**:
- `"level":"info","msg":"setting up manager"`
- `"level":"info","msg":"starting manager"`
- `"level":"info","msg":"Starting EventSource"`

### Step 1.2: Deploy Elasticsearch, Kibana, and APM

Deploy the complete Elastic stack using the `dp-config-es` Helm chart, which creates:
- Elasticsearch cluster
- Kibana instance
- APM server
- Index templates for Jaeger traces and user app logs
- Index lifecycle policies for automatic retention management
- Indices for service and span data

```bash
# Set release name
export TP_ES_RELEASE_NAME="dp-config-es"

# Deploy Elastic stack
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n elastic-system ${TP_ES_RELEASE_NAME} dp-config-es \
  --labels layer=2 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
domain: ${TP_DOMAIN}

# Elasticsearch configuration
es:
  version: "8.17.3"
  ingress:
    ingressClassName: ${TP_INGRESS_CLASS}
    service: ${TP_ES_RELEASE_NAME}-es-http
  storage:
    name: ${TP_DISK_STORAGE_CLASS}
  # Elasticsearch resource configuration (adjust as needed)
  resources:
    requests:
      cpu: "1"
      memory: "2Gi"
    limits:
      cpu: "2"
      memory: "4Gi"

# Kibana configuration
kibana:
  version: "8.17.3"
  ingress:
    ingressClassName: ${TP_INGRESS_CLASS}
    service: ${TP_ES_RELEASE_NAME}-kb-http
  # Kibana resource configuration (adjust as needed)
  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "1"
      memory: "2Gi"

# APM Server configuration
apm:
  enabled: true
  version: "8.17.3"
  ingress:
    ingressClassName: ${TP_INGRESS_CLASS}
    service: ${TP_ES_RELEASE_NAME}-apm-http
  # APM resource configuration (adjust as needed)
  resources:
    requests:
      cpu: "250m"
      memory: "512Mi"
    limits:
      cpu: "500m"
      memory: "1Gi"
EOF
```

**Monitor deployment**:

```bash
# Watch all pods in elastic-system namespace
kubectl get pods -n elastic-system -w

# Expected pods:
# elastic-operator-0                           1/1     Running
# dp-config-es-es-default-0                    1/1     Running
# dp-config-es-kb-xxxxxxxxx-xxxxx              1/1     Running
# dp-config-es-apm-xxxxxxxxx-xxxxx             1/1     Running
```

**Deployment typically takes 5-10 minutes.**

### Step 1.3: Verify Elastic Stack Installation

**Check Index Templates**:

Index templates define the structure and settings for Elasticsearch indices.

```bash
kubectl get -n elastic-system IndexTemplates
```

**Expected output**:
```
NAME                                         AGE
dp-config-es-jaeger-service-index-template   2m
dp-config-es-jaeger-span-index-template      2m
dp-config-es-user-apps-index-template        2m
```

**Check Indices**:

Indices store the actual trace and log data.

```bash
kubectl get -n elastic-system Indices
```

**Expected output**:
```
NAME                    AGE
jaeger-service-000001   2m
jaeger-span-000001      2m
```

**Check Index Lifecycle Policies**:

Policies manage index retention and rollover.

```bash
kubectl get -n elastic-system IndexLifecyclePolicies
```

**Expected output**:
```
NAME                                             AGE
dp-config-es-jaeger-index-30d-lifecycle-policy   2m
dp-config-es-user-index-60d-lifecycle-policy     2m
```

> [!IMPORTANT]
> If any of the above resources are missing, check the elastic-operator logs:
> ```bash
> kubectl logs -n elastic-system sts/elastic-operator --tail=100
> ```
> 
> Common issues:
> - Insufficient permissions: Check service account permissions
> - Storage issues: Verify PVC status with `kubectl get pvc -n elastic-system`
> - Resource constraints: Check node resources

**Verify Elasticsearch Service**:

```bash
kubectl get svc -n elastic-system ${TP_ES_RELEASE_NAME}-es-http

# Expected output shows ClusterIP service on port 9200
```

**Test Elasticsearch connectivity** (from within cluster):

```bash
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- \
  curl -k https://dp-config-es-es-http.elastic-system.svc.cluster.local:9200
```

### Step 1.4: Access Kibana Dashboard

**Get Kibana URL**:

```bash
kubectl get ingress -n elastic-system ${TP_ES_RELEASE_NAME}-kibana \
  -o jsonpath='{.spec.rules[0].host}'

# Expected output: kibana.<TP_DOMAIN>
```

**Get Kibana credentials**:

```bash
# Username is always 'elastic'
echo "Username: elastic"

# Get password from Kubernetes secret
kubectl get secret ${TP_ES_RELEASE_NAME}-es-elastic-user \
  -n elastic-system \
  -o jsonpath="{.data.elastic}" | base64 --decode; echo

# Example output:
# Password: a8Kx7vN2mQ5pY9wR3tL6hS4
```

**Access Kibana**:

1. Open browser to `https://kibana.<TP_DOMAIN>`
2. Login with username `elastic` and the password retrieved above
3. Accept any certificate warnings (if using self-signed certificates)

**Initial Kibana Setup**:

After logging in for the first time:

1. **Skip** the "Add data" wizard (we'll configure this later)
2. Navigate to **Stack Management** → **Index Patterns**
3. Create index patterns:
   - Pattern: `jaeger-span-*` (for distributed traces)
   - Pattern: `jaeger-service-*` (for service metadata)
4. Navigate to **Observability** → **APM** to view application performance data (after applications are deployed)

---

## Part 2: Prometheus and Grafana Installation

Prometheus provides metrics collection and Grafana provides visualization.

### Step 2.1: Install Prometheus Stack

The `kube-prometheus-stack` Helm chart deploys:
- Prometheus server (metrics storage and alerting)
- Grafana (visualization)
- AlertManager (alert routing)
- Node exporters (node metrics)
- kube-state-metrics (Kubernetes resource metrics)
- Pre-configured dashboards and alerts

```bash
helm upgrade --install --wait --timeout 1h --create-namespace --reuse-values \
  -n prometheus-system kube-prometheus-stack kube-prometheus-stack \
  --labels layer=2 \
  --repo "https://prometheus-community.github.io/helm-charts" --version "48.3.4" -f - <<EOF
# Grafana configuration
grafana:
  # Install useful plugins
  plugins:
    - grafana-piechart-panel
    - grafana-clock-panel
    - grafana-simple-json-datasource
  
  # Enable ingress for external access
  ingress:
    enabled: true
    ingressClassName: ${TP_INGRESS_CLASS}
    hosts:
    - grafana.${TP_DOMAIN}
    # Uncomment for TLS (requires cert-manager)
    # tls:
    # - secretName: grafana-tls
    #   hosts:
    #   - grafana.${TP_DOMAIN}
  
  # Grafana admin credentials (change in production!)
  adminUser: admin
  adminPassword: tibco-platform-admin
  
  # Additional data sources
  additionalDataSources:
  - name: Loki
    type: loki
    access: proxy
    url: http://loki.loki-system.svc.cluster.local:3100
    isDefault: false
    editable: true

# Prometheus configuration
prometheus:
  prometheusSpec:
    # Enable remote write receiver (for OTEL integration)
    enableRemoteWriteReceiver: true
    
    # External labels for multi-cluster setup
    externalLabels:
      cluster: ${TP_CLUSTER_NAME}
      environment: production
    
    # Remote write to OTEL collector (configured after DP deployment)
    # remoteWrite:
    # - url: http://otel-userapp-metrics.${DP_NAMESPACE}.svc.cluster.local:8889/api/v1/write
    
    # Storage configuration
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: ${TP_DISK_STORAGE_CLASS}
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 50Gi
    
    # Resource limits
    resources:
      requests:
        cpu: 1
        memory: 2Gi
      limits:
        cpu: 2
        memory: 4Gi
    
    # Retention period (default is 15 days)
    retention: 30d
    
    # Scrape interval
    scrapeInterval: 30s
    evaluationInterval: 30s

# AlertManager configuration
alertmanager:
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: ${TP_DISK_STORAGE_CLASS}
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi

# Node exporter configuration (metrics from all nodes)
nodeExporter:
  enabled: true

# kube-state-metrics (Kubernetes object metrics)
kube-state-metrics:
  enabled: true
EOF
```

**Monitor Prometheus deployment**:

```bash
# Watch pods
kubectl get pods -n prometheus-system -w

# Expected pods:
# alertmanager-kube-prometheus-stack-alertmanager-0    2/2     Running
# kube-prometheus-stack-grafana-xxxxxxxxx-xxxxx        3/3     Running
# kube-prometheus-stack-kube-state-metrics-xxxxx       1/1     Running
# kube-prometheus-stack-operator-xxxxxxxxx-xxxxx       1/1     Running
# kube-prometheus-stack-prometheus-node-exporter-xxx   1/1     Running
# prometheus-kube-prometheus-stack-prometheus-0        2/2     Running
```

### Step 2.2: Verify Prometheus Installation

**Check Prometheus Service**:

```bash
kubectl get svc -n prometheus-system kube-prometheus-stack-prometheus

# Expected: ClusterIP service on port 9090
```

**Access Prometheus UI** (port-forward):

```bash
kubectl port-forward -n prometheus-system \
  svc/kube-prometheus-stack-prometheus 9090:9090
```

Open browser to `http://localhost:9090` and verify:
- **Status** → **Targets**: Check all targets are "UP"
- **Status** → **Configuration**: Verify scrape configs
- Try a sample query: `up{job="kubernetes-nodes"}`

**Check AlertManager Service**:

```bash
kubectl get svc -n prometheus-system kube-prometheus-stack-alertmanager

# Expected: ClusterIP service on port 9093
```

### Step 2.3: Access Grafana Dashboard

**Get Grafana URL**:

```bash
kubectl get ingress -n prometheus-system kube-prometheus-stack-grafana \
  -o jsonpath='{.spec.rules[0].host}'

# Expected: grafana.<TP_DOMAIN>
```

**Get Grafana credentials**:

```bash
echo "Username: admin"
echo "Password: tibco-platform-admin"

# Or retrieve from secret:
kubectl get secret -n prometheus-system kube-prometheus-stack-grafana \
  -o jsonpath="{.data.admin-password}" | base64 --decode; echo
```

**Access Grafana**:

1. Open browser to `https://grafana.<TP_DOMAIN>`
2. Login with username `admin` and password
3. Navigate to **Dashboards** to see pre-installed dashboards:
   - **Kubernetes / Compute Resources / Cluster**
   - **Kubernetes / Compute Resources / Namespace (Pods)**
   - **Kubernetes / Compute Resources / Node (Pods)**
   - **Node Exporter / Nodes**
   - **Prometheus / Overview**

**Configure Prometheus Data Source** (if not auto-configured):

1. Navigate to **Configuration** → **Data Sources**
2. Click **Add data source**
3. Select **Prometheus**
4. Configure:
   - Name: `Prometheus`
   - URL: `http://kube-prometheus-stack-prometheus.prometheus-system.svc.cluster.local:9090`
   - Access: `Server (default)`
5. Click **Save & Test**

---

## Part 3: OTEL Collectors Configuration

OpenTelemetry collectors are deployed as part of the `dp-configure-namespace` chart and provide trace and metrics collection from TIBCO Platform applications.

### Step 3.1: Understanding OTEL Collectors

When you deploy `dp-configure-namespace` (as part of Data Plane setup), two OTEL collectors are automatically created:

1. **otel-userapp-traces**: Collects distributed traces from applications
   - Receives traces in Jaeger format (gRPC and HTTP)
   - Exports to Elasticsearch via Jaeger exporter
   - Listens on ports: 14250 (gRPC), 14268 (HTTP)

2. **otel-userapp-metrics**: Collects metrics from applications
   - Receives metrics in Prometheus format
   - Exports to Prometheus via remote write
   - Listens on ports: 8889 (Prometheus remote write)

**Architecture**:
```
Application → OTEL Trace Collector → Elasticsearch (Jaeger indices)
Application → OTEL Metrics Collector → Prometheus
```

### Step 3.2: Configure Trace Collection

The trace collector is configured via the `dp-configure-namespace` chart. If you've already deployed the Data Plane, the configuration looks like this:

```yaml
# Example from dp-configure-namespace deployment
otel:
  services:
    traces:
      grpc:
        enabled: true  # Jaeger gRPC receiver on port 14250
      http:
        enabled: true  # Jaeger HTTP receiver on port 14268

eso:
  enabled: true
  elasticsearch:
    endpoint: "https://dp-config-es-es-http.elastic-system.svc.cluster.local:9200"
    protocol: "https"
    secretName: "dp-config-es-es-elastic-user"
```

**Verify OTEL trace collector**:

```bash
# Check if DP_NAMESPACE is set
echo "DP_NAMESPACE: ${DP_NAMESPACE}"

# Get trace collector pod
kubectl get pods -n ${DP_NAMESPACE} -l app.kubernetes.io/name=opentelemetry-collector | grep traces

# Check logs
kubectl logs -n ${DP_NAMESPACE} -l app.kubernetes.io/name=opentelemetry-collector \
  -c otc-container --tail=50 | grep -i jaeger

# Expected log messages:
# "kind":"receiver","name":"jaeger/grpc","data_type":"traces"
# "kind":"exporter","name":"jaeger","data_type":"traces"
```

**Test trace collector** (manual trace submission):

```bash
# Port-forward to trace collector
kubectl port-forward -n ${DP_NAMESPACE} \
  svc/otel-userapp-traces 14268:14268

# In another terminal, send a test trace:
curl -X POST http://localhost:14268/api/traces \
  -H 'Content-Type: application/json' \
  -d '{
    "data": [{
      "traceID": "1234567890abcdef",
      "spans": [{
        "traceID": "1234567890abcdef",
        "spanID": "abcdef1234567890",
        "operationName": "test-operation",
        "startTime": '$(date +%s%N | cut -b1-16)',
        "duration": 1000,
        "tags": [{"key": "test", "type": "string", "value": "true"}]
      }]
    }]
  }'
```

**Verify in Kibana**:
1. Open Kibana
2. Navigate to **Discover**
3. Select index pattern `jaeger-span-*`
4. Search for `operationName: test-operation`

### Step 3.3: Configure Metrics Collection

The metrics collector is configured similarly:

```yaml
# Example from dp-configure-namespace deployment
otel:
  services:
    metrics:
      grpc:
        enabled: true
      http:
        enabled: true  # Prometheus remote write on port 8889

prom:
  enabled: true
  remoteWriteEndpoint: "http://kube-prometheus-stack-prometheus.prometheus-system.svc.cluster.local:9090/api/v1/write"
  queryEndpoint: "http://kube-prometheus-stack-prometheus.prometheus-system.svc.cluster.local:9090"
```

**Verify OTEL metrics collector**:

```bash
# Get metrics collector pod
kubectl get pods -n ${DP_NAMESPACE} -l app.kubernetes.io/name=opentelemetry-collector | grep metrics

# Check logs
kubectl logs -n ${DP_NAMESPACE} -l app.kubernetes.io/name=opentelemetry-collector \
  -c otc-container --tail=50 | grep -i prometheus

# Expected log messages:
# "kind":"receiver","name":"prometheus"
# "kind":"exporter","name":"prometheusremotewrite"
```

---

## Part 4: Integration with TIBCO Platform

### Step 4.1: Configure Ingress Trace Collection

To enable trace collection from the ingress controller (Traefik or NGINX), you need to reconfigure the ingress with OTEL settings.

**For NGINX Ingress**:

Update the `dp-config-aks` ingress deployment to enable OpenTelemetry:

```bash
# Ensure DP_NAMESPACE is set
export DP_NAMESPACE="ns"  # Your Data Plane namespace

helm upgrade --install --wait --timeout 1h \
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
    extraArgs:
      default-ssl-certificate: ingress-system/tp-certificate-main-ingress
    # OpenTelemetry configuration
    config:
      enable-opentelemetry: "true"
      log-level: debug
      opentelemetry-config: /etc/nginx/opentelemetry.toml
      opentelemetry-operation-name: "HTTP \$request_method \$service_name \$uri"
      opentelemetry-trust-incoming-span: "true"
      otel-max-export-batch-size: "512"
      otel-max-queuesize: "2048"
      otel-sampler: AlwaysOn
      otel-sampler-parent-based: "false"
      otel-sampler-ratio: "1.0"
      otel-schedule-delay-millis: "5000"
      otel-service-name: nginx-proxy
      otlp-collector-host: otel-userapp-traces.${DP_NAMESPACE}.svc
      otlp-collector-port: "4317"
    opentelemetry:
      enabled: true
EOF
```

**For Traefik Ingress**:

Update Traefik configuration:

```bash
helm upgrade --install --wait --timeout 1h \
  -n ingress-system dp-config-aks-ingress dp-config-aks \
  --labels layer=1 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" --version "^1.0.0" -f - <<EOF
clusterIssuer:
  create: false
httpIngress:
  enabled: false
traefik:
  enabled: true
  service:
    type: LoadBalancer
    annotations:
      external-dns.alpha.kubernetes.io/hostname: "*.${TP_DOMAIN}"
  tlsStore:
    default:
      defaultCertificate:
        secretName: tp-certificate-main-ingress
  # OpenTelemetry tracing
  tracing:
    otlp:
      http:
        endpoint: http://otel-userapp-traces.${DP_NAMESPACE}.svc.cluster.local:4318/v1/traces
    serviceName: traefik
EOF
```

**Verify ingress traces**:

1. Generate some traffic through the ingress
2. Open Kibana → **Discover**
3. Select `jaeger-span-*` index
4. Filter by `process.serviceName: "nginx-proxy"` or `process.serviceName: "traefik"`
5. View distributed traces showing ingress → application flow

### Step 4.2: Configure Application Traces

For BWCE applications to send traces, configure the BWCE application with OTEL environment variables.

**When deploying a BWCE application via Control Plane UI**:

1. Navigate to **Applications** → **Deploy Application**
2. Select your BWCE application
3. In the **Environment Variables** section, add:

```yaml
BW_OTEL_TRACES_ENABLED: "true"
BW_OTEL_EXPORTER_ENDPOINT: "http://otel-userapp-traces.ns.svc.cluster.local:4317"
BW_OTEL_SERVICE_NAME: "my-bwce-app"
```

**For applications already deployed**, update via API or redeploy with environment variables.

**Verify application traces**:

1. Invoke your BWCE application endpoints
2. Open Kibana → **APM** → **Services**
3. You should see your service name (`my-bwce-app`)
4. Click on the service to view:
   - Transaction overview
   - Error rate
   - Latency distribution
   - Service map (dependencies)

### Step 4.3: Configure Service Monitors

Service monitors enable Prometheus to scrape metrics from Data Plane services.

**Create ServiceMonitor for OTEL Metrics Collector**:

```bash
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: otel-collector-monitor
  namespace: ${DP_NAMESPACE}
  labels:
    app.kubernetes.io/name: otel-userapp-metrics
spec:
  endpoints:
  - interval: 30s
    path: /metrics
    port: prometheus
    scheme: http
  jobLabel: otel-collector
  selector:
    matchLabels:
      app.kubernetes.io/name: otel-userapp-metrics
EOF
```

**Verify ServiceMonitor**:

```bash
# Check if ServiceMonitor is created
kubectl get servicemonitor -n ${DP_NAMESPACE}

# Port-forward to Prometheus and check targets
kubectl port-forward -n prometheus-system svc/kube-prometheus-stack-prometheus 9090:9090

# Open browser to http://localhost:9090/targets
# Look for target: serviceMonitor/ns/otel-collector-monitor/0
```

**Create ServiceMonitor for Data Plane applications**:

Repeat for each deployed application that exposes Prometheus metrics.

---

## Part 5: Monitoring Best Practices

### 5.1: Index Management

**Monitor Elasticsearch disk usage**:

```bash
# Get Elasticsearch disk usage
kubectl exec -n elastic-system dp-config-es-es-default-0 -- \
  curl -s -k -u elastic:$(kubectl get secret dp-config-es-es-elastic-user -n elastic-system -o jsonpath="{.data.elastic}" | base64 --decode) \
  https://localhost:9200/_cat/allocation?v
```

**Adjust index lifecycle policies** if needed:

The default policies are:
- Jaeger indices: 30-day retention
- User app logs: 60-day retention

To modify, update the `dp-config-es` chart values:

```yaml
# Example: Change to 15-day retention
indexLifecyclePolicies:
  jaeger:
    retentionDays: 15
  userApps:
    retentionDays: 30
```

### 5.2: Metrics Retention

**Monitor Prometheus storage**:

```bash
kubectl exec -n prometheus-system prometheus-kube-prometheus-stack-prometheus-0 -c prometheus -- \
  du -sh /prometheus
```

**Adjust retention** (default is 30 days):

Update the Prometheus stack with new retention value:

```bash
helm upgrade --reuse-values \
  -n prometheus-system kube-prometheus-stack kube-prometheus-stack \
  --repo "https://prometheus-community.github.io/helm-charts" \
  --set prometheus.prometheusSpec.retention=60d
```

### 5.3: Alerting

**Create custom Prometheus alerts**:

```bash
kubectl apply -f - <<EOF
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: tibco-platform-alerts
  namespace: prometheus-system
  labels:
    prometheus: kube-prometheus-stack
spec:
  groups:
  - name: tibco-platform
    interval: 30s
    rules:
    - alert: DataPlaneDown
      expr: up{job="dp-core-infrastructure"} == 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Data Plane is down"
        description: "Data Plane {{ \$labels.instance }} has been down for more than 5 minutes."
    
    - alert: HighErrorRate
      expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
      for: 10m
      labels:
        severity: warning
      annotations:
        summary: "High error rate detected"
        description: "Error rate is {{ \$value }} for {{ \$labels.service }}"
EOF
```

### 5.4: Dashboard Management

**Import TIBCO Platform dashboards to Grafana**:

1. Navigate to Grafana → **Dashboards** → **Import**
2. Import community dashboards:
   - Dashboard ID **315**: Kubernetes Cluster Monitoring
   - Dashboard ID **12740**: Kubernetes Monitoring
   - Dashboard ID **13473**: Elasticsearch Cluster Monitoring

**Create custom dashboard for TIBCO Platform**:

1. Navigate to **Dashboards** → **New Dashboard**
2. Add panels for:
   - BWCE application request rate
   - Control Plane API latency
   - Data Plane pod health
   - Storage usage
   - Network traffic

### 5.5: Performance Tuning

**Optimize OTEL collector performance**:

If experiencing high load, adjust collector resources:

```yaml
# In dp-configure-namespace values
otelCollector:
  resources:
    limits:
      cpu: 1
      memory: 2Gi
    requests:
      cpu: 500m
      memory: 1Gi
```

**Reduce trace sampling** (if too much data):

```yaml
# In application configuration
BW_OTEL_SAMPLER_RATIO: "0.1"  # Sample 10% of traces
```

---

## Part 6: Troubleshooting

### Issue 1: Elasticsearch Pods Not Starting

**Symptoms**: Elasticsearch pods stuck in `Pending` or `CrashLoopBackOff`

**Diagnosis**:

```bash
kubectl describe pod -n elastic-system dp-config-es-es-default-0
kubectl logs -n elastic-system dp-config-es-es-default-0
```

**Common causes**:
1. **Insufficient memory**: Elasticsearch requires at least 2Gi
2. **PVC not binding**: Check `kubectl get pvc -n elastic-system`
3. **Storage class issues**: Verify storage class exists

**Solutions**:

```bash
# Check node resources
kubectl top nodes

# Check PVC status
kubectl get pvc -n elastic-system

# If PVC pending, check storage class
kubectl get storageclass ${TP_DISK_STORAGE_CLASS}

# Increase Elasticsearch memory limits
helm upgrade --reuse-values -n elastic-system dp-config-es dp-config-es \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" \
  --set es.resources.limits.memory=4Gi
```

### Issue 2: Kibana Cannot Connect to Elasticsearch

**Symptoms**: Kibana shows "Kibana server is not ready yet"

**Diagnosis**:

```bash
kubectl logs -n elastic-system -l common.k8s.elastic.co/type=kibana
```

**Look for**: Connection errors to Elasticsearch

**Solutions**:

```bash
# Verify Elasticsearch service
kubectl get svc -n elastic-system dp-config-es-es-http

# Test connectivity from Kibana pod
kubectl exec -n elastic-system -l common.k8s.elastic.co/type=kibana -- \
  curl -k https://dp-config-es-es-http:9200

# Restart Kibana
kubectl delete pod -n elastic-system -l common.k8s.elastic.co/type=kibana
```

### Issue 3: No Traces Appearing in Kibana

**Symptoms**: Applications deployed but no traces in Elasticsearch

**Diagnosis**:

```bash
# Check OTEL collector is running
kubectl get pods -n ${DP_NAMESPACE} -l app.kubernetes.io/name=opentelemetry-collector

# Check collector logs
kubectl logs -n ${DP_NAMESPACE} -l app.kubernetes.io/name=opentelemetry-collector \
  -c otc-container --tail=100
```

**Common causes**:
1. **Application not configured**: Missing OTEL environment variables
2. **Network connectivity**: OTEL collector not reachable
3. **Elasticsearch credentials**: Wrong credentials in OTEL config

**Solutions**:

```bash
# Verify application environment variables
kubectl describe pod -n ${DP_NAMESPACE} <app-pod-name> | grep -A10 "Environment:"

# Test connectivity from application to OTEL collector
kubectl exec -n ${DP_NAMESPACE} <app-pod-name> -- \
  nc -zv otel-userapp-traces.${DP_NAMESPACE}.svc 14268

# Check Elasticsearch credentials in OTEL config
kubectl get secret -n elastic-system dp-config-es-es-elastic-user -o yaml
```

### Issue 4: Prometheus Not Scraping Targets

**Symptoms**: Targets showing as "DOWN" in Prometheus

**Diagnosis**:

```bash
# Port-forward to Prometheus
kubectl port-forward -n prometheus-system svc/kube-prometheus-stack-prometheus 9090:9090

# Check targets: http://localhost:9090/targets
```

**Common causes**:
1. **ServiceMonitor not created**: Missing ServiceMonitor resource
2. **Label mismatch**: ServiceMonitor selector doesn't match service labels
3. **Network policy**: Blocking Prometheus from scraping

**Solutions**:

```bash
# Verify ServiceMonitor exists
kubectl get servicemonitor -A

# Check ServiceMonitor labels match service labels
kubectl get svc -n ${DP_NAMESPACE} <service-name> --show-labels
kubectl get servicemonitor -n ${DP_NAMESPACE} <servicemonitor-name> -o yaml

# Test connectivity from Prometheus pod
kubectl exec -n prometheus-system prometheus-kube-prometheus-stack-prometheus-0 -c prometheus -- \
  wget -O- http://<service-name>.<namespace>.svc.cluster.local:<port>/metrics
```

### Issue 5: Grafana Dashboard Shows No Data

**Symptoms**: Grafana panels show "No data"

**Diagnosis**:

```bash
# Check Grafana logs
kubectl logs -n prometheus-system -l app.kubernetes.io/name=grafana

# Verify Prometheus data source
# Navigate to Grafana → Configuration → Data Sources → Prometheus
# Click "Test" button
```

**Solutions**:

```bash
# Verify Prometheus has data
kubectl port-forward -n prometheus-system svc/kube-prometheus-stack-prometheus 9090:9090
# Open browser to http://localhost:9090
# Run query: up

# Reconfigure Prometheus data source in Grafana
# URL should be: http://kube-prometheus-stack-prometheus.prometheus-system.svc.cluster.local:9090

# Restart Grafana
kubectl delete pod -n prometheus-system -l app.kubernetes.io/name=grafana
```

### Issue 6: High Storage Usage

**Symptoms**: Elasticsearch or Prometheus volumes filling up

**Diagnosis**:

```bash
# Check Elasticsearch disk usage
kubectl exec -n elastic-system dp-config-es-es-default-0 -- df -h /usr/share/elasticsearch/data

# Check Prometheus disk usage
kubectl exec -n prometheus-system prometheus-kube-prometheus-stack-prometheus-0 -c prometheus -- \
  df -h /prometheus
```

**Solutions**:

```bash
# Reduce Elasticsearch retention (delete old indices)
kubectl exec -n elastic-system dp-config-es-es-default-0 -- \
  curl -X DELETE -k -u elastic:$(kubectl get secret dp-config-es-es-elastic-user -n elastic-system -o jsonpath="{.data.elastic}" | base64 --decode) \
  "https://localhost:9200/jaeger-span-$(date -d '30 days ago' +%Y-%m-%d)*"

# Reduce Prometheus retention
helm upgrade --reuse-values -n prometheus-system kube-prometheus-stack \
  --repo "https://prometheus-community.github.io/helm-charts" \
  --set prometheus.prometheusSpec.retention=15d

# Increase PVC size (requires dynamic provisioning)
kubectl patch pvc -n elastic-system elasticsearch-data-dp-config-es-es-default-0 \
  -p '{"spec":{"resources":{"requests":{"storage":"100Gi"}}}}'
```

---

## References

### Official Documentation

- [Elastic Cloud on Kubernetes (ECK)](https://www.elastic.co/guide/en/cloud-on-k8s/current/index.html)
- [Elasticsearch 8.17 Documentation](https://www.elastic.co/guide/en/elasticsearch/reference/8.17/index.html)
- [Kibana 8.17 Documentation](https://www.elastic.co/guide/en/kibana/8.17/index.html)
- [Prometheus Documentation](https://prometheus.io/docs/introduction/overview/)
- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
- [kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

### TIBCO Platform Resources

- [TIBCO Platform Documentation](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm)
- [tp-helm-charts GitHub](https://github.com/TIBCOSoftware/tp-helm-charts)
- [AKS Workshop - Data Plane](https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/docs/workshop/aks/data-plane)
- [dp-config-es Chart](https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/charts/dp-config-es)
- [dp-configure-namespace Chart](https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/charts/dp-configure-namespace)

### Related Guides

- [CP and DP Setup Guide](how-to-cp-and-dp-aks-setup-guide.md)
- [DP-only Setup Guide](how-to-dp-aks-setup-guide.md)
- [Prerequisites Checklist](prerequisites-checklist-for-customer.md)
- [DNS Configuration](how-to-add-dns-records-aks-azure.md)

---

## Summary

You have successfully set up a comprehensive observability stack for TIBCO Platform on AKS!

### What You Deployed

- ✅ Elastic ECK operator 2.16.0
- ✅ Elasticsearch 8.17.3 for log and trace storage
- ✅ Kibana 8.17.3 for visualization
- ✅ APM Server 8.17.3 for application performance monitoring
- ✅ Prometheus 48.3.4 for metrics collection
- ✅ Grafana for metrics visualization
- ✅ OTEL collectors for traces and metrics
- ✅ Pre-configured index templates and lifecycle policies
- ✅ ServiceMonitors for automatic scraping

### Access Information

| Component | URL | Credentials |
|-----------|-----|-------------|
| Kibana | `https://kibana.<TP_DOMAIN>` | Username: `elastic`<br>Password: From secret |
| Grafana | `https://grafana.<TP_DOMAIN>` | Username: `admin`<br>Password: `tibco-platform-admin` |
| Prometheus | Port-forward 9090 | N/A |

### Next Steps

1. **Configure Application Tracing**: Add OTEL environment variables to your BWCE/Flogo apps
2. **Create Custom Dashboards**: Build Grafana dashboards for your specific use cases
3. **Set Up Alerting**: Configure AlertManager rules for proactive monitoring
4. **Optimize Performance**: Tune OTEL collectors and adjust retention policies
5. **Monitor Storage**: Regularly check Elasticsearch and Prometheus disk usage

### Useful Commands

```bash
# View all observability components
kubectl get pods -n elastic-system
kubectl get pods -n prometheus-system
kubectl get pods -n ${DP_NAMESPACE} -l app.kubernetes.io/name=opentelemetry-collector

# Get Kibana password
kubectl get secret dp-config-es-es-elastic-user -n elastic-system -o jsonpath="{.data.elastic}" | base64 --decode; echo

# Check Elasticsearch indices
kubectl exec -n elastic-system dp-config-es-es-default-0 -- \
  curl -k -u elastic:<password> https://localhost:9200/_cat/indices?v

# View Prometheus targets
kubectl port-forward -n prometheus-system svc/kube-prometheus-stack-prometheus 9090:9090
# Open http://localhost:9090/targets

# Collect logs for troubleshooting
kubectl logs -n elastic-system sts/elastic-operator > elastic-operator.log
kubectl logs -n ${DP_NAMESPACE} -l app.kubernetes.io/name=opentelemetry-collector > otel-collector.log
```

---

**Document Version**: 1.0  
**Last Updated**: January 22, 2026  
**Maintained By**: TIBCO Platform Team
