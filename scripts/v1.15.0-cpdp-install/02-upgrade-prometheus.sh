#!/bin/bash
# Upgrade Prometheus Stack from 48.3.4 to 69.3.3

set -e

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-environment-v1.15.sh"

echo "=========================================="
echo "Upgrading Prometheus Stack"
echo "=========================================="

# Check current version
CURRENT_VERSION=$(helm list -n ${PROMETHEUS_NAMESPACE} -o json | jq -r '.[] | select(.name=="kube-prometheus-stack") | .chart' | cut -d'-' -f4)

echo "Current version: ${CURRENT_VERSION}"
echo "Target version: 69.3.3"

if [[ "${CURRENT_VERSION}" == "69.3.3" ]]; then
    echo "✅ Prometheus is already at version 69.3.3"
    exit 0
fi

# Create backup
create_backup

# Get current values
echo ""
echo "📝 Backing up current Helm values..."
helm get values kube-prometheus-stack -n ${PROMETHEUS_NAMESPACE} > "${BACKUP_DIR}/prometheus-values.yaml"

# Update Helm repo
echo ""
echo "📦 Updating Helm repository..."
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Create enhanced values for v1.15.0
echo ""
echo "📝 Creating enhanced Prometheus values..."
cat > /tmp/prometheus-upgrade-values.yaml <<EOF
prometheus:
  prometheusSpec:
    retention: 30d
    storageSpec:
      volumeClaimTemplate:
        spec:
          storageClassName: ${RWO_STORAGE_CLASS}
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 100Gi
    resources:
      requests:
        cpu: 1000m
        memory: 4Gi
      limits:
        cpu: 2000m
        memory: 8Gi
    # Enable service monitors for TIBCO Platform
    serviceMonitorSelectorNilUsesHelmValues: false
    podMonitorSelectorNilUsesHelmValues: false
    ruleSelectorNilUsesHelmValues: false

grafana:
  enabled: true
  adminPassword: "admin123"  # CHANGE THIS in production!
  persistence:
    enabled: true
    storageClassName: ${RWO_STORAGE_CLASS}
    size: 10Gi
  ingress:
    enabled: true
    ingressClassName: ${INGRESS_CLASS}
    annotations:
      cert-manager.io/cluster-issuer: ${CERT_ISSUER}
    hosts:
      - grafana.${TP_BASE_DNS_DOMAIN}
    tls:
      - secretName: grafana-tls
        hosts:
          - grafana.${TP_BASE_DNS_DOMAIN}
  datasources:
    datasources.yaml:
      apiVersion: 1
      datasources:
      - name: Prometheus
        type: prometheus
        url: http://kube-prometheus-stack-prometheus.${PROMETHEUS_NAMESPACE}:9090
        access: proxy
        isDefault: true
      # Elasticsearch datasource for logs (if available)
      - name: Elasticsearch
        type: elasticsearch
        url: http://dp-config-es-es-http.${ELASTIC_NAMESPACE}:9200
        access: proxy
        database: "[logs-]YYYY.MM.DD"
        jsonData:
          timeField: "@timestamp"
          esVersion: "8.0.0"
          logLevelField: "level"
          logMessageField: "message"

alertmanager:
  enabled: true
  alertmanagerSpec:
    storage:
      volumeClaimTemplate:
        spec:
          storageClassName: ${RWO_STORAGE_CLASS}
          accessModes: ["ReadWriteOnce"]
          resources:
            requests:
              storage: 10Gi

# Enable additional service monitors
kubeStateMetrics:
  enabled: true

nodeExporter:
  enabled: true

# Disable components not needed
kubeEtcd:
  enabled: false

kubeControllerManager:
  enabled: false

kubeScheduler:
  enabled: false
EOF

# Perform upgrade
echo ""
echo "🚀 Upgrading Prometheus stack to 69.3.3..."
echo "This may take several minutes..."

helm upgrade kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace ${PROMETHEUS_NAMESPACE} \
  --version 69.3.3 \
  --values /tmp/prometheus-upgrade-values.yaml \
  --timeout 20m \
  --wait

# Verify upgrade
echo ""
echo "✅ Checking deployment status..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=prometheus \
  -n ${PROMETHEUS_NAMESPACE} \
  --timeout=300s

kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=grafana \
  -n ${PROMETHEUS_NAMESPACE} \
  --timeout=300s

# Display access information
echo ""
echo "=========================================="
echo "✅ Prometheus Stack Upgraded Successfully"
echo "=========================================="
echo ""
echo "📊 Access Information:"
echo "Grafana URL: https://grafana.${TP_BASE_DNS_DOMAIN}"
echo "Grafana Username: admin"
echo "Grafana Password: admin123 (CHANGE THIS!)"
echo ""
echo "Prometheus URL (in-cluster): http://kube-prometheus-stack-prometheus.${PROMETHEUS_NAMESPACE}:9090"
echo ""
echo "To get Grafana password: kubectl get secret kube-prometheus-stack-grafana -n ${PROMETHEUS_NAMESPACE} -o jsonpath='{.data.admin-password}' | base64 -d"
echo ""

# Cleanup
rm -f /tmp/prometheus-upgrade-values.yaml

echo "Next: Run 03-verify-observability.sh to verify the complete observability stack"
