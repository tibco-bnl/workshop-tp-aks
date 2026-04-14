#!/bin/bash
# Post-Installation Verification for TIBCO Platform v1.15.0

set -e

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-environment-v1.15.sh"

echo "=========================================="
echo "TIBCO Platform v1.15.0 Post-Install Verification"
echo "=========================================="

# Function to check DNS resolution
check_dns() {
    local domain=$1
    echo -n "Checking DNS for ${domain}... "
    if dig +short ${domain} | grep -q "${INGRESS_LOAD_BALANCER_IP}"; then
        echo "✅ OK (${INGRESS_LOAD_BALANCER_IP})"
        return 0
    else
        echo "❌ FAILED (expected ${INGRESS_LOAD_BALANCER_IP})"
        return 1
    fi
}

# 1. Check Control Plane
echo ""
echo "=== Control Plane Verification ==="
echo ""
echo "📦 Control Plane Pods:"
kubectl get pods -n ${TP_CP_NAMESPACE}

echo ""
echo "🌐 Control Plane Ingress:"
kubectl get ingress -n ${TP_CP_NAMESPACE}

echo ""
echo "🔍 DNS Resolution:"
check_dns "admin.${TP_BASE_DNS_DOMAIN}" || true
check_dns "tunnel.${TP_BASE_DNS_DOMAIN}" || true

# 2. Check Data Plane
echo ""
echo "=== Data Plane Verification ==="
echo ""
echo "📦 Data Plane Pods:"
kubectl get pods -n ${TP_DP_NAMESPACE}

echo ""
echo "🌐 Data Plane Services:"
kubectl get svc -n ${TP_DP_NAMESPACE}

echo ""
echo "📊 Capability Status:"
kubectl get pods -n ${TP_DP_NAMESPACE} | grep -E "bwce|flogo|ems|provisioner" || echo "No capability pods found yet"

# 3. Test Control Plane connectivity from within cluster
echo ""
echo "=== Connectivity Tests ==="
echo ""
echo "🔍 Testing Control Plane MY domain from within cluster..."
kubectl run test-cp-my --image=curlimages/curl --rm -it --restart=Never -n ${TP_DP_NAMESPACE} --timeout=30s -- \
  curl -k -I -m 10 https://admin.${TP_BASE_DNS_DOMAIN} 2>/dev/null | head -5 || echo "⚠️  Connection test failed"

echo ""
echo "🔍 Testing Control Plane TUNNEL domain from within cluster..."
kubectl run test-cp-tunnel --image=curlimages/curl --rm -it --restart=Never -n ${TP_DP_NAMESPACE} --timeout=30s -- \
  curl -k -I -m 10 https://tunnel.${TP_BASE_DNS_DOMAIN} 2>/dev/null | head -5 || echo "⚠️  Connection test failed"

# 4. Check Observability
echo ""
echo "=== Observability Stack ==="
echo ""
echo "📊 Elasticsearch:"
kubectl get elasticsearch -n ${ELASTIC_NAMESPACE}

echo ""
echo "📊 Prometheus:"
kubectl get pods -n ${PROMETHEUS_NAMESPACE} -l app.kubernetes.io/name=prometheus

echo ""
echo "📊 Grafana:"
kubectl get pods -n ${PROMETHEUS_NAMESPACE} -l app.kubernetes.io/name=grafana

# 5. Summary
echo ""
echo "=========================================="
echo "📋 Installation Summary"
echo "=========================================="
echo ""
echo "✅ Components Installed:"
echo "  - Control Plane v${TP_VERSION}"
echo "  - Data Plane v${TP_VERSION}"
echo "  - Elasticsearch 8.17.3"
echo "  - Prometheus Stack 69.3.3"
echo "  - NGINX Ingress"
echo ""
echo "🌐 Access URLs (v1.15.0 Simplified DNS):"
echo "  Control Plane: https://admin.${TP_BASE_DNS_DOMAIN}"
echo "  Kibana: https://kibana.${TP_BASE_DNS_DOMAIN}"
echo "  Grafana: https://grafana.${TP_BASE_DNS_DOMAIN}"
echo ""
echo "📊 Data Plane:"
echo "  Instance ID: ${TP_DP_INSTANCE_ID}"
echo "  Application Domain: *.${TP_DP_BASE_DNS_DOMAIN}"
echo ""
echo "🔐 Credentials:"
echo "  Get Elasticsearch password: kubectl get secret dp-config-es-es-elastic-user -n ${ELASTIC_NAMESPACE} -o go-template='{{.data.elastic | base64decode}}'"
echo "  Get Grafana password: kubectl get secret kube-prometheus-stack-grafana -n ${PROMETHEUS_NAMESPACE} -o jsonpath='{.data.admin-password}' | base64 -d"
echo ""
echo "📋 Next Steps:"
echo "  1. Access Control Plane UI and verify dashboard"
echo "  2. Check Data Plane connection status"
echo "  3. Verify capabilities are available"
echo "  4. Deploy a test BWCE or Flogo application"
echo "  5. Check logs in Kibana"
echo "  6. View metrics in Grafana"
echo ""
echo "🔍 Troubleshooting Commands:"
echo "  View CP logs: kubectl logs -n ${TP_CP_NAMESPACE} -l app.kubernetes.io/component=cp-core -f"
echo "  View DP logs: kubectl logs -n ${TP_DP_NAMESPACE} -l app.kubernetes.io/component=dp-core-ops -f"
echo "  Check DNS: dig +short admin.${TP_BASE_DNS_DOMAIN}"
echo ""
