#!/bin/bash
# Verify Observability Stack (Elastic + Prometheus)

set -e

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-environment-v1.15.sh"

echo "=========================================="
echo "Verifying Observability Stack"
echo "=========================================="

# Check Elasticsearch
echo ""
echo "📊 Elasticsearch Status:"
kubectl get elasticsearch -n ${ELASTIC_NAMESPACE} 2>/dev/null || echo "⚠️  No Elasticsearch found"

echo ""
echo "📦 Elastic Pods:"
kubectl get pods -n ${ELASTIC_NAMESPACE} | grep -E "NAME|elastic" || echo "No Elastic pods found"

# Check Kibana
echo ""
echo "📊 Kibana Status:"
kubectl get kibana -n ${ELASTIC_NAMESPACE} 2>/dev/null || echo "⚠️  No Kibana found"

echo ""
echo "📦 Kibana Pods:"
kubectl get pods -n ${ELASTIC_NAMESPACE} | grep -E "NAME|kibana" || echo "No Kibana pods found"

# Check Prometheus
echo ""
echo "📊 Prometheus Status:"
kubectl get pods -n ${PROMETHEUS_NAMESPACE} -l app.kubernetes.io/name=prometheus

echo ""
echo "📊 Grafana Status:"
kubectl get pods -n ${PROMETHEUS_NAMESPACE} -l app.kubernetes.io/name=grafana

# Check ingress for observability
echo ""
echo "📊 Observability Ingress Resources:"
kubectl get ingress -n ${ELASTIC_NAMESPACE} 2>/dev/null || echo "No ingress in ${ELASTIC_NAMESPACE}"
kubectl get ingress -n ${PROMETHEUS_NAMESPACE} 2>/dev/null || echo "No ingress in ${PROMETHEUS_NAMESPACE}"

# Get Elasticsearch password
if kubectl get secret dp-config-es-es-elastic-user -n ${ELASTIC_NAMESPACE} &>/dev/null; then
    ES_PASSWORD=$(kubectl get secret dp-config-es-es-elastic-user \
      -n ${ELASTIC_NAMESPACE} \
      -o go-template='{{.data.elastic | base64decode}}')
    
    echo ""
    echo "=========================================="
    echo "📊 Observability Access Information"
    echo "=========================================="
    echo ""
    echo "Kibana URL: https://kibana.${TP_BASE_DNS_DOMAIN}"
    echo "Kibana Username: elastic"
    echo "Kibana Password: ${ES_PASSWORD}"
    echo ""
    echo "Grafana URL: https://grafana.${TP_BASE_DNS_DOMAIN}"
    echo "Grafana Username: admin"
    echo "Grafana Password: Run to get -> kubectl get secret kube-prometheus-stack-grafana -n ${PROMETHEUS_NAMESPACE} -o jsonpath='{.data.admin-password}' | base64 -d"
    echo ""
else
    echo ""
    echo "⚠️  Could not retrieve Elasticsearch password"
fi

# Test Elasticsearch connectivity
echo ""
echo "🔍 Testing Elasticsearch connectivity..."
if kubectl run test-es --rm -i --restart=Never --image=curlimages/curl -n ${ELASTIC_NAMESPACE} -- \
  curl -s -u "elastic:${ES_PASSWORD}" -k https://dp-config-es-es-http:9200/_cluster/health 2>/dev/null | grep -q "green\|yellow"; then
    echo "✅ Elasticsearch is accessible"
else
    echo "⚠️  Elasticsearch health check failed or cluster not ready"
fi

# Check versions
echo ""
echo "📦 Component Versions:"
echo "---"
ES_VERSION=$(kubectl get elasticsearch dp-config-es -n ${ELASTIC_NAMESPACE} -o jsonpath='{.spec.version}' 2>/dev/null || echo "N/A")
echo "Elasticsearch: ${ES_VERSION}"

PROM_VERSION=$(helm list -n ${PROMETHEUS_NAMESPACE} -o json | jq -r '.[] | select(.name=="kube-prometheus-stack") | .chart' 2>/dev/null || echo "N/A")
echo "Prometheus Stack: ${PROM_VERSION}"

ECK_VERSION=$(helm list -n ${ELASTIC_NAMESPACE} -o json | jq -r '.[] | select(.name=="eck-operator") | .chart' 2>/dev/null || echo "N/A")
echo "ECK Operator: ${ECK_VERSION}"

echo ""
echo "=========================================="
echo "✅ Observability Stack Verification Complete"
echo "=========================================="
echo ""
echo "Expected for v1.15.0:"
echo "  - Elasticsearch: 8.17.3 ✅"
echo "  - Prometheus Stack: kube-prometheus-stack-69.3.3"
echo "  - ECK Operator: eck-operator-2.16.0 ✅"
echo ""
