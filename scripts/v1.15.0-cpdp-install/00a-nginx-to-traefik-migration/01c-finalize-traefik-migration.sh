#!/bin/bash
# Finalize Traefik Migration and Remove NGINX

set -e

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-environment-v1.15.sh"

echo "=========================================="
echo "Finalize Traefik Migration"
echo "=========================================="

# Verify Traefik is running
if ! kubectl get deployment traefik -n ${INGRESS_NAMESPACE} &>/dev/null; then
    echo "❌ ERROR: Traefik not found in ${INGRESS_NAMESPACE}"
    echo "Run ./01b-migrate-nginx-to-traefik.sh first"
    exit 1
fi

# Verify Traefik has LoadBalancer IP
TRAEFIK_IP=$(kubectl get svc traefik -n ${INGRESS_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
if [[ -z "${TRAEFIK_IP}" ]]; then
    echo "❌ ERROR: Traefik LoadBalancer IP not assigned"
    exit 1
fi

echo "✅ Traefik is running with IP: ${TRAEFIK_IP}"

# Check for ingress resources still using nginx
echo ""
echo "🔍 Checking for ingress resources still using nginx..."
NGINX_INGRESSES=$(kubectl get ingress -A -o json | jq -r '.items[] | select(.spec.ingressClassName=="nginx") | "\(.metadata.namespace)/\(.metadata.name)"' | wc -l | tr -d ' ')

if [[ "${NGINX_INGRESSES}" != "0" ]]; then
    echo ""
    echo "⚠️  WARNING: Found ${NGINX_INGRESSES} ingress resources still using nginx:"
    kubectl get ingress -A -o json | jq -r '.items[] | select(.spec.ingressClassName=="nginx") | "\(.metadata.namespace)/\(.metadata.name)"'
    echo ""
    echo "Migrate them using:"
    echo "  /tmp/migrate-ingress-resources.sh <namespace>"
    echo ""
    read -p "Continue with NGINX removal anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Cancelled. Please migrate all ingress resources first."
        exit 1
    fi
fi

# Test Traefik ingress (if Kibana exists)
echo ""
echo "🔍 Testing Traefik ingress..."
if kubectl get ingress kibana -n elastic-system &>/dev/null; then
    KIBANA_INGRESS_CLASS=$(kubectl get ingress kibana -n elastic-system -o jsonpath='{.spec.ingressClassName}')
    if [[ "${KIBANA_INGRESS_CLASS}" == "traefik" ]]; then
        echo "Testing Kibana via Traefik..."
        if curl -k -I -m 10 https://kibana.${TP_BASE_DNS_DOMAIN} 2>/dev/null | head -1 | grep -q "HTTP"; then
            echo "✅ Kibana is accessible via Traefik"
        else
            echo "⚠️  WARNING: Could not access Kibana via Traefik"
            echo "Verify DNS and ingress configuration"
        fi
    else
        echo "⚠️  Kibana ingress still uses: ${KIBANA_INGRESS_CLASS}"
    fi
fi

# Create backup
create_backup

# Backup NGINX configuration before removal
echo ""
echo "📦 Backing up NGINX configuration..."
helm get values dp-config-aks-nginx -n ${INGRESS_NAMESPACE} > "${BACKUP_DIR}/nginx-helm-values.yaml" 2>/dev/null || true
helm get all dp-config-aks-nginx -n ${INGRESS_NAMESPACE} > "${BACKUP_DIR}/nginx-helm-all.yaml" 2>/dev/null || true

# Remove NGINX Helm releases
echo ""
echo "🗑️  Removing NGINX ingress controller..."

if helm list -n ${INGRESS_NAMESPACE} | grep -q "dp-config-aks-nginx"; then
    helm uninstall dp-config-aks-nginx -n ${INGRESS_NAMESPACE}
    echo "✅ Removed dp-config-aks-nginx"
fi

if helm list -n ${INGRESS_NAMESPACE} | grep -q "dp-config-aks-ingress-certificate"; then
    helm uninstall dp-config-aks-ingress-certificate -n ${INGRESS_NAMESPACE}
    echo "✅ Removed dp-config-aks-ingress-certificate"
fi

# Wait for NGINX resources to be cleaned up
echo ""
echo "⏳ Waiting for NGINX LoadBalancer to be released..."
echo "   Azure needs to release IP: ${INGRESS_LOAD_BALANCER_IP}"
sleep 20

# Verify NGINX is gone
if kubectl get deployment -n ${INGRESS_NAMESPACE} | grep -q nginx; then
    echo "⚠️  WARNING: Some NGINX resources still exist"
    kubectl get deployment,svc -n ${INGRESS_NAMESPACE} | grep nginx || true
else
    echo "✅ NGINX resources removed"
fi

# Now reclaim the original LoadBalancer IP for Traefik
echo ""
echo "🔄 Updating Traefik to use original LoadBalancer IP: ${INGRESS_LOAD_BALANCER_IP}"
echo ""

# Delete and recreate Traefik service with the reserved IP
# This is more reliable than patching for IP changes
echo "Updating Traefik service to reclaim ${INGRESS_LOAD_BALANCER_IP}..."

# Update the Helm release to include the reserved IP
helm upgrade traefik traefik/traefik \
    --namespace ${INGRESS_NAMESPACE} \
    --reuse-values \
    --set service.loadBalancerIP="${INGRESS_LOAD_BALANCER_IP}" \
    --wait

echo ""
echo "⏳ Waiting for LoadBalancer IP assignment..."
for i in {1..30}; do
    CURRENT_IP=$(kubectl get svc traefik -n ${INGRESS_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [[ "${CURRENT_IP}" == "${INGRESS_LOAD_BALANCER_IP}" ]]; then
        echo "✅ Traefik now using reserved IP: ${INGRESS_LOAD_BALANCER_IP}"
        break
    fi
    echo "Waiting... ($i/30) Current IP: ${CURRENT_IP}"
    sleep 5
done

# Verify the IP was assigned correctly
FINAL_IP=$(kubectl get svc traefik -n ${INGRESS_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [[ "${FINAL_IP}" != "${INGRESS_LOAD_BALANCER_IP}" ]]; then
    echo ""
    echo "⚠️  WARNING: Traefik IP did not change to reserved IP"
    echo "   Expected: ${INGRESS_LOAD_BALANCER_IP}"
    echo "   Current: ${FINAL_IP}"
    echo ""
    echo "Azure may need more time to release the IP."
    echo "Check status with: kubectl get svc traefik -n ${INGRESS_NAMESPACE}"
fi

# Wait for external-dns to update DNS records
echo ""
echo "⏳ Waiting for external-dns to update DNS records..."
sleep 30

echo ""
echo "🔍 Verifying DNS update..."
nslookup test.${TP_BASE_DNS_DOMAIN} 8.8.8.8 | grep -A1 "Name:" || echo "DNS not yet propagated"

# Update ingress class to default
echo ""
echo "🔧 Setting Traefik as default ingress class..."
kubectl annotate ingressclass traefik ingressclass.kubernetes.io/is-default-class=true --overwrite
kubectl annotate ingressclass nginx ingressclass.kubernetes.io/is-default-class- 2>/dev/null || true

# Display final status
echo ""
echo "=========================================="
echo "✅ Migration to Traefik Complete"
echo "=========================================="
echo ""
echo "📊 Final Configuration:"
echo "---"
echo "Ingress Classes:"
kubectl get ingressclass
echo ""
echo "Traefik Service:"
kubectl get svc -n ${INGRESS_NAMESPACE} | grep -E "NAME|traefik"
echo ""

FINAL_IP=$(kubectl get svc traefik -n ${INGRESS_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "LoadBalancer IP: ${FINAL_IP}"
if [[ "${FINAL_IP}" == "${INGRESS_LOAD_BALANCER_IP}" ]]; then
    echo "✅ Successfully reclaimed reserved IP"
else
    echo "⚠️  IP mismatch - may need manual intervention"
fi
echo "DNS: *.${TP_BASE_DNS_DOMAIN} → ${FINAL_IP}"
echo ""
echo "📋 Migration Summary:"
TOTAL_TRAEFIK=$(kubectl get ingress -A -o jsonpath='{range .items[?(@.spec.ingressClassName=="traefik")]}{.metadata.name}{"\n"}{end}' | wc -l | tr -d ' ')
echo "  ✅ Ingresses using Traefik: ${TOTAL_TRAEFIK}"
echo "  ✅ NGINX removed successfully"
echo ""
echo "📋 Next Steps:"
echo "1. Verify DNS propagation (may take 1-2 minutes):"
echo "   nslookup kibana.${TP_BASE_DNS_DOMAIN}"
echo ""
echo "2. Test all applications:"
echo "   curl -k -I https://kibana.${TP_BASE_DNS_DOMAIN}"
echo "   curl -k -I https://grafana.${TP_BASE_DNS_DOMAIN}"
echo ""
echo "3. Update environment configuration:"
echo "   sed -i.bak 's/INGRESS_CONTROLLER=\"nginx\"/INGRESS_CONTROLLER=\"traefik\"/' 00-environment-v1.15.sh"
echo ""
echo "4. Monitor Traefik:"
echo "   kubectl logs -n ${INGRESS_NAMESPACE} -l app.kubernetes.io/name=traefik -f"
echo ""
echo "5. Access Traefik Dashboard (if enabled):"
echo "   kubectl port-forward -n ${INGRESS_NAMESPACE} svc/traefik 9000:9000"
echo "   Open: http://localhost:9000/dashboard/"
echo ""
echo "6. Proceed with Prometheus upgrade:"
echo "   ./02-upgrade-prometheus.sh"
echo ""
echo "7. Install TIBCO Platform Control Plane:"
echo "   ./04-install-controlplane.sh"
echo ""
