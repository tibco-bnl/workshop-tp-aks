#!/bin/bash
set -e

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-environment-v1.15.sh"

echo "=========================================="
echo "Gradual Migration: NGINX → Traefik"
echo "=========================================="

NAMESPACE=$1

if [[ -z "$NAMESPACE" ]]; then
    echo ""
    echo "Usage: $0 <namespace>"
    echo ""
    echo "📋 Namespaces with NGINX ingresses:"
    kubectl get ingress -A -o jsonpath='{range .items[?(@.spec.ingressClassName=="nginx")]}{.metadata.namespace}{"\n"}{end}' | sort -u | while read ns; do
        count=$(kubectl get ingress -n "$ns" -o jsonpath='{range .items[?(@.spec.ingressClassName=="nginx")]}{.metadata.name}{"\n"}{end}' | wc -l | tr -d ' ')
        echo "  • $ns ($count ingresses)"
    done
    echo ""
    echo "Example: $0 elastic-system"
    echo ""
    echo "Recommended order:"
    echo "  1. elastic-system (monitoring - easy to verify)"
    echo "  2. prometheus-system (monitoring - easy to verify)"
    echo "  3. ai (multiple apps)"
    echo "  4. bpm (production app)"
    exit 1
fi

echo ""
echo "🔍 Analyzing namespace: $NAMESPACE"
echo ""

# Get list of nginx ingresses in the namespace
INGRESSES=$(kubectl get ingress -n "$NAMESPACE" -o jsonpath='{range .items[?(@.spec.ingressClassName=="nginx")]}{.metadata.name}{"\n"}{end}')

if [[ -z "$INGRESSES" ]]; then
    echo "✅ No NGINX ingresses found in namespace $NAMESPACE"
    echo "   All ingresses may already be using Traefik or another controller."
    exit 0
fi

echo "📋 NGINX Ingresses to migrate in $NAMESPACE:"
echo "$INGRESSES" | while read ing; do
    host=$(kubectl get ingress "$ing" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].host}')
    echo "  • $ing → $host"
done
echo ""

read -p "Continue with migration? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Migration cancelled"
    exit 1
fi

# Create backup
BACKUP_DIR="./backups/$(date +%Y%m%d-%H%M%S)-migrate-$NAMESPACE"
mkdir -p "$BACKUP_DIR"
echo ""
echo "📦 Creating backup in $BACKUP_DIR..."
kubectl get ingress -n "$NAMESPACE" -o yaml > "$BACKUP_DIR/ingresses-before.yaml"
echo "✅ Backup created"

# Migrate each ingress
echo ""
echo "🔄 Migrating ingresses..."
echo ""

MIGRATED_COUNT=0
FAILED_COUNT=0

while IFS= read -r ingress_name; do
    echo "  Migrating: $ingress_name"
    
    # Get the host for verification
    HOST=$(kubectl get ingress "$ingress_name" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].host}')
    
    # Patch the ingress to use traefik
    if kubectl patch ingress "$ingress_name" -n "$NAMESPACE" --type=merge -p '{"spec":{"ingressClassName":"traefik"}}'; then
        echo "    ✅ Patched to use traefik"
        ((MIGRATED_COUNT++))
        
        # Test if host is reachable (if external-dns has updated)
        if [[ -n "$HOST" ]]; then
            echo "    🔍 Testing: $HOST"
            sleep 2
            if curl -k -I -s --max-time 5 "https://$HOST" | head -1 | grep -E "HTTP/(1.1|2) (200|301|302|401|403)" > /dev/null; then
                echo "    ✅ Host is reachable via Traefik"
            else
                echo "    ⚠️  Could not verify host (may need DNS propagation or service restart)"
            fi
        fi
    else
        echo "    ❌ Failed to patch"
        ((FAILED_COUNT++))
    fi
    echo ""
done <<< "$INGRESSES"

# Save post-migration state
kubectl get ingress -n "$NAMESPACE" -o yaml > "$BACKUP_DIR/ingresses-after.yaml"

echo "=========================================="
echo "✅ Migration Complete for $NAMESPACE"
echo "=========================================="
echo ""
echo "📊 Summary:"
echo "  ✅ Migrated: $MIGRATED_COUNT"
if [[ $FAILED_COUNT -gt 0 ]]; then
    echo "  ❌ Failed: $FAILED_COUNT"
fi
echo ""
echo "📋 Current Ingress Status in $NAMESPACE:"
kubectl get ingress -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name,CLASS:.spec.ingressClassName,HOSTS:.spec.rules[*].host
echo ""

# Check if any nginx ingresses remain in the namespace
REMAINING_NGINX=$(kubectl get ingress -n "$NAMESPACE" -o jsonpath='{range .items[?(@.spec.ingressClassName=="nginx")]}{.metadata.name}{"\n"}{end}' | wc -l | tr -d ' ')

if [[ "$REMAINING_NGINX" -eq 0 ]]; then
    echo "✅ All ingresses in $NAMESPACE migrated to Traefik!"
else
    echo "⚠️  $REMAINING_NGINX NGINX ingress(es) still remain"
fi

echo ""
echo "🔍 Verification Steps:"
echo "  1. Check if services are accessible:"
while IFS= read -r ingress_name; do
    HOST=$(kubectl get ingress "$ingress_name" -n "$NAMESPACE" -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || echo "")
    if [[ -n "$HOST" ]]; then
        echo "     curl -k -I https://$HOST"
    fi
done <<< "$INGRESSES"
echo ""
echo "  2. Check Traefik logs:"
echo "     kubectl logs -n ingress-system -l app.kubernetes.io/name=traefik --tail=50"
echo ""
echo "  3. Monitor pods in namespace:"
echo "     kubectl get pods -n $NAMESPACE"
echo ""

# Check overall migration status across all namespaces
echo "=========================================="
echo "Overall Migration Status"
echo "=========================================="
echo ""
TOTAL_NGINX=$(kubectl get ingress -A -o jsonpath='{range .items[?(@.spec.ingressClassName=="nginx")]}{.metadata.name}{"\n"}{end}' | wc -l | tr -d ' ')
TOTAL_TRAEFIK=$(kubectl get ingress -A -o jsonpath='{range .items[?(@.spec.ingressClassName=="traefik")]}{.metadata.name}{"\n"}{end}' | wc -l | tr -d ' ')

echo "📊 Cluster-wide Ingress Controllers:"
echo "  • Traefik: $TOTAL_TRAEFIK ingresses"
echo "  • NGINX: $TOTAL_NGINX ingresses"
echo ""

if [[ "$TOTAL_NGINX" -eq 0 ]]; then
    echo "✅ All ingresses migrated to Traefik!"
    echo ""
    echo "🔄 Next Steps:"
    echo "  1. Verify all applications are accessible"
    echo "  2. Run finalization script to remove NGINX:"
    echo "     ./01c-finalize-traefik-migration.sh"
else
    echo "📋 Remaining namespaces with NGINX ingresses:"
    kubectl get ingress -A -o jsonpath='{range .items[?(@.spec.ingressClassName=="nginx")]}{.metadata.namespace}{"\n"}{end}' | sort -u | while read ns; do
        count=$(kubectl get ingress -n "$ns" -o jsonpath='{range .items[?(@.spec.ingressClassName=="nginx")]}{.metadata.name}{"\n"}{end}' | wc -l | tr -d ' ')
        echo "  • $ns ($count ingresses)"
    done
    echo ""
    echo "🔄 Next: Migrate next namespace:"
    kubectl get ingress -A -o jsonpath='{range .items[?(@.spec.ingressClassName=="nginx")]}{.metadata.namespace}{"\n"}{end}' | sort -u | head -1 | while read ns; do
        echo "  $0 $ns"
    done
fi
echo ""
