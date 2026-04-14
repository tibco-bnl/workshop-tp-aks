#!/bin/bash
# Quick migration script for remaining namespaces

set -e

echo "=========================================="
echo "Migrating Remaining Namespaces"
echo "=========================================="
echo ""

# Backup directory
BACKUP_DIR="./backups/20260318-144625-manual-migration"

echo "Step 3: Migrating ai namespace (8 ingresses)"
echo "---"
kubectl get ingress -n ai -o yaml > "$BACKUP_DIR/ai-before.yaml"

# Migrate all ai ingresses
for ingress in $(kubectl get ingress -n ai -o jsonpath='{.items[?(@.spec.ingressClassName=="nginx")].metadata.name}'); do
    echo "  Migrating: $ingress"
    kubectl patch ingress "$ingress" -n ai --type=merge -p '{"spec":{"ingressClassName":"traefik"}}'
done

echo "✅ ai namespace migrated"
echo ""

echo "Step 4: Migrating bpm namespace (1 ingress)"
echo "---"
kubectl get ingress -n bpm -o yaml > "$BACKUP_DIR/bpm-before.yaml"

# Migrate bpm ingresses
for ingress in $(kubectl get ingress -n bpm -o jsonpath='{.items[?(@.spec.ingressClassName=="nginx")].metadata.name}'); do
    echo "  Migrating: $ingress"
    kubectl patch ingress "$ingress" -n bpm --type=merge -p '{"spec":{"ingressClassName":"traefik"}}'
done

echo "✅ bpm namespace migrated"
echo ""

echo "=========================================="
echo "✅ All Namespaces Migrated!"
echo "=========================================="
echo ""
echo "Summary:"
kubectl get ingress -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,CLASS:.spec.ingressClassName' | grep -E 'NAMESPACE|traefik|nginx'
echo ""
echo "Migration complete! All ingresses now use Traefik."
echo ""
echo "Next step: Finalize migration and remove NGINX"
echo "  ./01c-finalize-traefik-migration.sh"
echo ""
