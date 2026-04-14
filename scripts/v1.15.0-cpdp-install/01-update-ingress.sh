#!/bin/bash
# Update NGINX Ingress with v1.15.0 DNS and IP whitelisting

set -e

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-environment-v1.15.sh"

echo "=========================================="
echo "Updating NGINX Ingress Configuration"
echo "=========================================="

# Create backup
create_backup

# Update ingress service annotation for correct DNS
echo ""
echo "📝 Updating DNS annotation from *.dp1.kul.atsnl-emea.azure.dataplanes.pro to *.${TP_BASE_DNS_DOMAIN}..."

kubectl annotate svc dp-config-aks-nginx-ingress-nginx-controller \
  -n ${INGRESS_NAMESPACE} \
  "external-dns.alpha.kubernetes.io/hostname=*.${TP_BASE_DNS_DOMAIN}" \
  --overwrite

echo "✅ DNS annotation updated"

# Add IP whitelisting if configured
if [[ "${TP_AUTHORIZED_IP_RANGE}" != "0.0.0.0/0" ]]; then
    echo ""
    echo "🔒 Adding IP whitelisting: ${TP_AUTHORIZED_IP_RANGE}..."
    
    kubectl annotate svc dp-config-aks-nginx-ingress-nginx-controller \
      -n ${INGRESS_NAMESPACE} \
      "service.beta.kubernetes.io/load-balancer-source-ranges=${TP_AUTHORIZED_IP_RANGE}" \
      --overwrite
    
    echo "✅ IP whitelisting configured"
else
    echo ""
    echo "⚠️  WARNING: No IP whitelisting configured (0.0.0.0/0 allows all traffic)"
    echo "For production, update TP_AUTHORIZED_IP_RANGE in environment file"
fi

# Verify configuration
echo ""
echo "📋 Current Ingress Configuration:"
echo "---"
kubectl get svc dp-config-aks-nginx-ingress-nginx-controller \
  -n ${INGRESS_NAMESPACE} \
  -o jsonpath='{.metadata.annotations}' | jq .

echo ""
echo "✅ Ingress configuration updated successfully"
echo ""
echo "Next: Verify DNS resolution with: dig +short test.${TP_BASE_DNS_DOMAIN}"
