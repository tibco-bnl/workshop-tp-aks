#!/bin/bash
set -e

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-environment-v1.15.sh"

echo "=========================================="
echo "Enabling Traefik Dashboard"
echo "=========================================="

# Check if Traefik is running
if ! kubectl get deployment traefik -n ingress-system &>/dev/null; then
    echo "❌ Traefik not found. Please install Traefik first."
    exit 1
fi

echo ""
echo "🔧 Enabling Traefik dashboard..."

# Update Traefik to enable dashboard
helm upgrade traefik traefik/traefik \
    --namespace ingress-system \
    --reuse-values \
    --set ingressRoute.dashboard.enabled=true \
    --set ports.traefik.port=9000 \
    --set ports.traefik.expose.default=true \
    --wait

echo ""
echo "✅ Traefik dashboard enabled!"
echo ""
echo "=========================================="
echo "Access Traefik Dashboard"
echo "=========================================="
echo ""
echo "Method 1: Port Forward (Local Access)"
echo "  kubectl port-forward -n ingress-system svc/traefik 9000:9000"
echo "  Then open: http://localhost:9000/dashboard/"
echo ""
echo "Method 2: Create Ingress (External Access)"
echo "  Note: Requires TLS certificate for dashboard.${TP_BASE_DNS_DOMAIN}"
echo ""
echo "To create external access ingress:"
cat <<'EODASHBOARD'
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: traefik-dashboard
  namespace: ingress-system
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    external-dns.alpha.kubernetes.io/hostname: dashboard.dp1.atsnl-emea.azure.dataplanes.pro
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - dashboard.dp1.atsnl-emea.azure.dataplanes.pro
    secretName: traefik-dashboard-tls
  rules:
  - host: dashboard.dp1.atsnl-emea.azure.dataplanes.pro
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: traefik
            port:
              number: 9000
EOF
EODASHBOARD
echo ""
echo "Then access: https://dashboard.${TP_BASE_DNS_DOMAIN}/dashboard/"
echo ""
