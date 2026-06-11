# TIBCO Platform v1.17.0 Quick Reference Guide

**TIBCO Platform Version**: 1.17.0 | **Status**: ✅ Production Ready

---

## Quick Access URLs

| Service | URL Pattern | Notes |
|---------|-------------|-------|
| **Admin Console** | `https://admin.<domain>` | Replace `<domain>` with your CP domain |
| **MailDev UI** | `https://mail.<domain>` | SMTP testing interface |

---

## Essential Commands

### Get Admin Password
```bash
kubectl get secret tp-cp-web-server -n cp1-ns -o jsonpath='{.data.TSC_ADMIN_PASSWORD}' | base64 -d && echo
```

### Check All Pods
```bash
kubectl get pods -n cp1-ns
```

### View Helm Releases
```bash
helm list -n cp1-ns
```

### Check Ingress Routes
```bash
kubectl get ingress -n cp1-ns
```

### View Logs (Control Plane Core)
```bash
kubectl logs -n cp1-ns -l app=tp-cp-infra --tail=100
```

### Check Database Connectivity
```bash
kubectl run psql-test -n cp1-ns --rm -it --image=postgres:15 -- \
  psql -h postgresql.tibco-ext.svc.cluster.local -U postgres -d postgres
```

---

## Helm Charts (v1.17.0)

| Chart | Version | Release Name |
|-------|---------|--------------|
| tibco-cp-base | 1.17.0 | tibco-cp-base |
| tibco-cp-bw | 1.17.0 | tibco-cp-bw |
| tibco-cp-flogo | 1.17.0 | tibco-cp-flogo |
| tibco-cp-devhub | 1.17.0 | tibco-cp-devhub |
| tibco-cp-addon-eventprocessing | 1.17.0 | tibco-cp-addon-eventprocessing |
| tp-dp-monitor-agent | 1.17.13 | tp-dp-monitor-agent |
| tp-dp-license-file | 1.17.0 | tp-dp-license-file |
| tp-cp-proxy | 1.17.4 | tp-cp-proxy |

---

## New in v1.17.0 — Quick Reference

### Webhook Receiver Setup
```bash
# After configuring Webhook Receiver in Control Plane UI,
# test egress connectivity from cp1-ns to your webhook endpoint
kubectl run curl-test -n cp1-ns --rm -it --image=curlimages/curl -- \
  curl -X POST <your-webhook-url> \
  -H "Content-Type: application/json" \
  -d '{"test": "tibco-platform-webhook-test"}'

# Check NetworkPolicy allows egress from cp1-ns
kubectl get networkpolicy -n cp1-ns
```

### OpenSearch for Observability
```bash
# Deploy OpenSearch Operator on AKS (alternative to ECK)
kubectl apply -f https://opensearch-operator-release-url/opensearch-operator.yaml

# Create OpenSearch cluster in observability namespace
kubectl apply -f opensearch-cluster.yaml -n elastic-system

# Verify OpenSearch is running
kubectl get pods -n elastic-system -l app=opensearch

# Apply TIBCO Platform index templates
# See: https://docs.tibco.com/pub/platform-cp/1.17.0/doc/html/UserGuide/jaeger-opensearch-index-template.htm
```

### BW5CE Hawk REST API (Port 8090)
```bash
# Test Hawk REST API in BW5CE pod
kubectl exec -it <bw5ce-pod-name> -n dp1-ns -- \
  curl -s http://localhost:8090/commands

# Add port 8090 NetworkPolicy if restrictive policies are in place
# Example patch for Data Plane namespace NetworkPolicy
kubectl patch networkpolicy <bw5ce-netpol> -n dp1-ns \
  --type=json \
  -p='[{"op":"add","path":"/spec/ingress/-","value":{"ports":[{"port":8090,"protocol":"TCP"}]}}]'
```

### Custom Fluentbit Config (BW5/BW6 Containers)
```yaml
# Example Helm values for custom Fluentbit configuration in BW6 Capability
# Set during capability provisioning or via Control Plane UI update
fluentbit:
  customConfig: |
    [INPUT]
        Name tail
        Path /var/log/containers/*.log
        Parser docker
        Tag bw6.*
    [OUTPUT]
        Name  es
        Match bw6.*
        Host  ${ELASTICSEARCH_HOST}
        Port  9200
        Index bw6-logs
```

### Flogo Recipe Customization
```yaml
# Navigate in Control Plane UI:
# Data Planes → <DP Name> → Capabilities → Flogo → Provision/Update
# Use the Recipe Editor to customize resource allocations:
resources:
  requests:
    cpu: "500m"
    memory: "512Mi"
  limits:
    cpu: "2000m"
    memory: "2Gi"
```

---

## Configuration Quick Reference

### Key Variables
```bash
TP_VERSION=1.17.0
CP_INSTANCE_ID=cp1

# Container registry (same as v1.16.0)
TP_CONTAINER_REGISTRY=csgprdusw2reposaas.jfrog.io
TP_CONTAINER_REGISTRY_REPOSITORY=tibco-platform-docker-dev
```

### Upgrade to v1.17.0
```bash
# Add/update Helm repo
helm repo add tibco-platform https://tibcosoftware.github.io/tp-helm-charts
helm repo update

# Upgrade Control Plane base
helm upgrade tibco-cp-base tibco-platform/tibco-cp-base \
  --version 1.17.0 \
  -n cp1-ns \
  -f cp1-values.yaml

# Upgrade BW capability
helm upgrade tibco-cp-bw tibco-platform/tibco-cp-bw \
  --version 1.17.0 \
  -n cp1-ns \
  -f bw-values.yaml

# Upgrade Flogo capability
helm upgrade tibco-cp-flogo tibco-platform/tibco-cp-flogo \
  --version 1.17.0 \
  -n cp1-ns \
  -f flogo-values.yaml
```

---

## Troubleshooting

### Pods Not Starting
```bash
kubectl describe pod <pod-name> -n cp1-ns
kubectl get events -n cp1-ns --sort-by='.lastTimestamp'
```

### Helm Release in Failed State
```bash
# Check actual pod status (helm status may be misleading)
kubectl get pods -n cp1-ns
# If pods are running, the platform is operational
```

### Database Connection Issues
```bash
kubectl run psql-test -n cp1-ns --rm -it --image=postgres:15 -- \
  psql -h postgresql.tibco-ext.svc.cluster.local -U postgres
```

### Ingress Not Accessible
```bash
kubectl get ingress -n cp1-ns
kubectl describe ingress <ingress-name> -n cp1-ns
kubectl get svc -n traefik
```

### Elasticsearch/OpenSearch Connection
```bash
kubectl get pods -n elastic-system
kubectl logs -n elastic-system <opensearch-or-es-pod> --tail=50
```
