#!/bin/bash
# Quick status check for Traefik migration

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-environment-v1.15.sh" 2>/dev/null || true

echo "=========================================="
echo "Traefik Migration Status"
echo "=========================================="
echo ""

# Check LoadBalancer IPs
echo "📊 LoadBalancer Services:"
echo "---"
kubectl get svc -n ingress-system -o custom-columns=NAME:.metadata.name,TYPE:.spec.type,EXTERNAL-IP:.status.loadBalancer.ingress[0].ip,AGE:.metadata.creationTimestamp 2>/dev/null | grep -E "NAME|nginx|traefik" || echo "No ingress services found"

echo ""
echo "🌐 DNS Resolution:"
echo "---"
TEST_HOST=$(nslookup test.dp1.atsnl-emea.azure.dataplanes.pro 8.8.8.8 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}')
if [[ -n "$TEST_HOST" ]]; then
    echo "*.dp1.atsnl-emea.azure.dataplanes.pro → $TEST_HOST"
    
    # Check which controller this IP belongs to
    NGINX_IP=$(kubectl get svc -n ingress-system -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name | contains("nginx")) | .status.loadBalancer.ingress[0].ip' 2>/dev/null | head -1)
    TRAEFIK_IP=$(kubectl get svc traefik -n ingress-system -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null)
    
    if [[ "$TEST_HOST" == "$NGINX_IP" ]]; then
        echo "→ Pointing to NGINX"
    elif [[ "$TEST_HOST" == "$TRAEFIK_IP" ]]; then
        echo "→ Pointing to Traefik ✓"
    fi
else
    echo "DNS not resolved"
fi

echo ""
echo "🎯 Ingress Controllers:"
echo "---"
kubectl get ingressclass -o custom-columns=NAME:.metadata.name,CONTROLLER:.spec.controller,DEFAULT:.metadata.annotations."ingressclass\.kubernetes\.io/is-default-class" 2>/dev/null || echo "No ingress classes found"

# Check for old TIBCO DP ingress class
OLD_DP_ID="d31hm0jnpmmc73b2qfeg"
OLD_INGRESSCLASS="tibco-dp-${OLD_DP_ID}"
if kubectl get ingressclass "${OLD_INGRESSCLASS}" &>/dev/null; then
    echo ""
    echo "⚠️  Note: Old TIBCO Data Plane ingress class detected"
    echo "   Class: ${OLD_INGRESSCLASS}"
    echo "   DP ID: ${OLD_DP_ID} (from previous installation)"
    echo "   Status: Can be removed after v1.15.0 installation"
    echo "   Cleanup: ./cleanup-old-dp.sh"
fi

echo ""
echo "📋 Ingress Resources by Controller:"
echo "---"

# Count nginx ingresses
NGINX_COUNT=$(kubectl get ingress -A -o json 2>/dev/null | jq '[.items[] | select(.spec.ingressClassName=="nginx")] | length' 2>/dev/null || echo "0")
echo "NGINX:   $NGINX_COUNT ingresses"

if [[ "$NGINX_COUNT" -gt 0 ]]; then
    echo "  Namespaces:"
    kubectl get ingress -A -o json 2>/dev/null | jq -r '.items[] | select(.spec.ingressClassName=="nginx") | "  • \(.metadata.namespace) (\(.metadata.name))"' 2>/dev/null | sort -u
fi

# Count traefik ingresses
TRAEFIK_COUNT=$(kubectl get ingress -A -o json 2>/dev/null | jq '[.items[] | select(.spec.ingressClassName=="traefik")] | length' 2>/dev/null || echo "0")
echo "Traefik: $TRAEFIK_COUNT ingresses"

if [[ "$TRAEFIK_COUNT" -gt 0 ]]; then
    echo "  Namespaces:"
    kubectl get ingress -A -o json 2>/dev/null | jq -r '.items[] | select(.spec.ingressClassName=="traefik") | "  • \(.metadata.namespace)"' 2>/dev/null | sort -u
fi

echo ""
echo "🔍 Migration Progress:"
echo "---"

TOTAL=$((NGINX_COUNT + TRAEFIK_COUNT))
if [[ $TOTAL -gt 0 ]]; then
    PERCENT=$((TRAEFIK_COUNT * 100 / TOTAL))
    echo "Progress: $TRAEFIK_COUNT/$TOTAL migrated ($PERCENT%)"
    
    if [[ "$NGINX_COUNT" -eq 0 ]]; then
        echo "Status: ✅ All ingresses migrated to Traefik"
        echo ""
        echo "Next step: Run finalization script"
        echo "  ./01c-finalize-traefik-migration.sh"
    else
        echo "Status: ⏳ Migration in progress"
        echo ""
        echo "Next steps:"
        kubectl get ingress -A -o json 2>/dev/null | jq -r '.items[] | select(.spec.ingressClassName=="nginx") | .metadata.namespace' 2>/dev/null | sort -u | head -1 | while read ns; do
            echo "  ./01f-migrate-namespace.sh $ns"
        done
    fi
else
    echo "No ingresses found"
fi

echo ""
echo "🔧 Supporting Services:"
echo "---"

# Check external-dns
EXTDNS_STATUS=$(kubectl get deploy external-dns -n external-dns-system -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "NotFound")
echo "external-dns: $([[ "$EXTDNS_STATUS" == "True" ]] && echo "✅ Running" || echo "❌ Not running")"

# Check cert-manager
CERTMGR_STATUS=$(kubectl get deploy cert-manager -n cert-manager -o jsonpath='{.status.conditions[?(@.type=="Available")].status}' 2>/dev/null || echo "NotFound")
echo "cert-manager: $([[ "$CERTMGR_STATUS" == "True" ]] && echo "✅ Running" || echo "❌ Not running")"

# Check Traefik pods
if kubectl get deployment traefik -n ingress-system &>/dev/null; then
    TRAEFIK_READY=$(kubectl get deployment traefik -n ingress-system -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    TRAEFIK_DESIRED=$(kubectl get deployment traefik -n ingress-system -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "0")
    echo "Traefik pods: $TRAEFIK_READY/$TRAEFIK_DESIRED ready"
fi

echo ""
echo "=========================================="
echo ""
echo "For detailed information, see: MIGRATION-SUMMARY.md"
echo "To check logs: kubectl logs -n external-dns-system deploy/external-dns --tail=20"
echo ""
