#!/bin/bash
set -e

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-environment-v1.15.sh"

echo "=========================================="
echo "Updating external-dns Configuration"
echo "=========================================="

# Backup current external-dns deployment
echo ""
echo "📦 Backing up current external-dns configuration..."
kubectl get deploy external-dns -n external-dns-system -o yaml > ./backups/$(date +%Y%m%d-%H%M%S)-external-dns-backup.yaml
echo "✅ Backup created"

echo ""
echo "📋 Current external-dns configuration:"
kubectl get deploy external-dns -n external-dns-system -o jsonpath='{.spec.template.spec.containers[0].args}' | jq -r '.[]'
echo ""

# Update external-dns to:
# 1. Use correct DNS zone (dp1.atsnl-emea.azure.dataplanes.pro instead of dp1.kul.atsnl-emea.azure.dataplanes.pro)
# 2. Remove ingress-class filter to watch both nginx and traefik
# 3. Add annotation filter to be more selective

echo "🔧 Updating external-dns to work with correct DNS zone and both ingress controllers..."
echo ""
echo "Changes:"
echo "  ✓ Domain filter: dp1.kul.atsnl-emea.azure.dataplanes.pro → ${TP_BASE_DNS_DOMAIN}"
echo "  ✓ Ingress class: nginx → (removed - will watch both nginx and traefik)"
echo "  ✓ Added: annotation filter for external-dns.alpha.kubernetes.io/hostname"
echo ""

# Patch the deployment
kubectl patch deployment external-dns -n external-dns-system --type=json -p='[
  {
    "op": "replace",
    "path": "/spec/template/spec/containers/0/args",
    "value": [
      "--log-level=info",
      "--log-format=text",
      "--interval=1m",
      "--source=service",
      "--source=ingress",
      "--policy=upsert-only",
      "--registry=txt",
      "--domain-filter='"${TP_BASE_DNS_DOMAIN}"'",
      "--provider=azure",
      "--annotation-filter=external-dns.alpha.kubernetes.io/hostname",
      "--txt-wildcard-replacement=wildcard"
    ]
  }
]'

echo ""
echo "⏳ Waiting for external-dns to restart..."
kubectl rollout status deployment external-dns -n external-dns-system --timeout=60s

echo ""
echo "📋 Updated external-dns configuration:"
kubectl get deploy external-dns -n external-dns-system -o jsonpath='{.spec.template.spec.containers[0].args}' | jq -r '.[]'

echo ""
echo "✅ external-dns updated successfully!"
echo ""
echo "📊 Checking external-dns logs..."
sleep 5
kubectl logs -n external-dns-system -l app.kubernetes.io/name=external-dns --tail=20

echo ""
echo "=========================================="
echo "✅ external-dns Configuration Updated"
echo "=========================================="
echo ""
echo "external-dns will now:"
echo "  ✓ Watch services and ingresses in: ${TP_BASE_DNS_DOMAIN}"
echo "  ✓ Monitor both nginx and traefik ingress resources"
echo "  ✓ Create DNS records only for resources with annotation:"
echo "    external-dns.alpha.kubernetes.io/hostname"
echo ""
echo "🔄 Next: Update Traefik service annotation to trigger DNS update"
echo "   kubectl annotate svc traefik -n ingress-system \\"
echo "     external-dns.alpha.kubernetes.io/hostname=\"*.${TP_BASE_DNS_DOMAIN}\" --overwrite"
echo ""
echo "   Then wait 1-2 minutes and check:"
echo "   kubectl logs -n external-dns-system -l app.kubernetes.io/name=external-dns --tail=30"
echo ""
