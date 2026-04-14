#!/bin/bash
# Enable Traefik Dashboard with Secure Access

set -e

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-environment-v1.15.sh"

echo "=========================================="
echo "Enabling Traefik Dashboard"
echo "=========================================="

# Check if Traefik is installed
if ! kubectl get deployment traefik -n ${INGRESS_NAMESPACE} &>/dev/null; then
    echo "❌ ERROR: Traefik not found in ${INGRESS_NAMESPACE}"
    echo "Run ./01b-migrate-nginx-to-traefik.sh first"
    exit 1
fi

# Create IngressRoute for dashboard
echo ""
echo "📊 Creating Traefik Dashboard IngressRoute..."

cat <<EOF | kubectl apply -f -
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: traefik-dashboard
  namespace: ${INGRESS_NAMESPACE}
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(\`traefik.${TP_BASE_DNS_DOMAIN}\`)
      kind: Rule
      services:
        - name: api@internal
          kind: TraefikService
  tls:
    secretName: traefik-dashboard-tls
EOF

echo "✅ Dashboard IngressRoute created"

# Create DNS record for dashboard
echo ""
echo "📋 DNS Configuration:"
echo "Add DNS A record:"
echo "  Name: traefik"
echo "  Zone: ${TP_BASE_DNS_DOMAIN}"
echo "  Value: ${INGRESS_LOAD_BALANCER_IP}"

read -p "Create DNS record now? (requires Azure CLI) (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    ZONE_NAME="${TP_BASE_DNS_DOMAIN}"
    RESOURCE_GROUP="kul-atsbnl"
    
    echo "Creating DNS record..."
    az network dns record-set a add-record \
      --resource-group ${RESOURCE_GROUP} \
      --zone-name ${ZONE_NAME} \
      --record-set-name "traefik" \
      --ipv4-address ${INGRESS_LOAD_BALANCER_IP} \
      2>/dev/null && echo "✅ DNS record created" || echo "⚠️  DNS record already exists or creation failed"
fi

echo ""
echo "=========================================="
echo "✅ Traefik Dashboard Access"
echo "=========================================="
echo ""
echo "🌐 External Access (via HTTPS):"
echo "   URL: https://traefik.${TP_BASE_DNS_DOMAIN}/dashboard/"
echo "   Note: Requires DNS propagation (1-2 minutes)"
echo ""
echo "🔧 Local Access (via port-forward):"
echo "   kubectl port-forward -n ${INGRESS_NAMESPACE} svc/traefik 9000:9000"
echo "   Then open: http://localhost:9000/dashboard/"
echo ""
echo "📊 Dashboard Features:"
echo "   - Live traffic monitoring"
echo "   - Route configuration"
echo "   - Service health"
echo "   - Metrics and statistics"
echo ""
echo "🔍 Verify access:"
echo "   curl -k https://traefik.${TP_BASE_DNS_DOMAIN}/dashboard/ -I"
echo ""
