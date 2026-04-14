#!/bin/bash
# Cleanup old TIBCO Data Plane resources

set -e

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-environment-v1.15.sh" 2>/dev/null || true

echo "=========================================="
echo "Cleanup Old TIBCO Data Plane Resources"
echo "=========================================="
echo ""

OLD_DP_ID="d31hm0jnpmmc73b2qfeg"
OLD_INGRESSCLASS="tibco-dp-${OLD_DP_ID}"

echo "ℹ️  Old TIBCO Data Plane Information:"
echo "  DP ID: ${OLD_DP_ID}"
echo "  Ingress Class: ${OLD_INGRESSCLASS}"
echo ""

# Check if the old ingress class exists
if ! kubectl get ingressclass "${OLD_INGRESSCLASS}" &>/dev/null; then
    echo "✅ Old ingress class '${OLD_INGRESSCLASS}' not found"
    echo "   Nothing to clean up."
    exit 0
fi

echo "📋 Current ingress class details:"
kubectl get ingressclass "${OLD_INGRESSCLASS}" -o yaml | grep -A5 "metadata:\|controller:"
echo ""

# Check if any ingresses are using this class
INGRESS_COUNT=$(kubectl get ingress -A -o json | jq -r --arg class "${OLD_INGRESSCLASS}" '.items[] | select(.spec.ingressClassName==$class) | "\(.metadata.namespace)/\(.metadata.name)"' | wc -l | tr -d ' ')

if [[ "${INGRESS_COUNT}" != "0" ]]; then
    echo "⚠️  WARNING: ${INGRESS_COUNT} ingress resource(s) still using this class:"
    kubectl get ingress -A -o json | jq -r --arg class "${OLD_INGRESSCLASS}" '.items[] | select(.spec.ingressClassName==$class) | "  • \(.metadata.namespace)/\(.metadata.name)"'
    echo ""
    echo "Please migrate them first before removing this ingress class."
    exit 1
fi

# Check if the controller pods are still running
echo "🔍 Checking for old TIBCO Data Plane controller pods..."
OLD_PODS=$(kubectl get pods -A -o json | jq -r --arg dpid "${OLD_DP_ID}" '.items[] | select(.metadata.name | contains($dpid)) | "\(.metadata.namespace)/\(.metadata.name)"')

if [[ -n "${OLD_PODS}" ]]; then
    echo ""
    echo "⚠️  WARNING: Old Data Plane pods still running:"
    echo "${OLD_PODS}" | while read pod; do
        echo "  • ${pod}"
    done
    echo ""
    read -p "Remove old Data Plane deployment? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "🗑️  Removing old Data Plane pods..."
        kubectl get pods -A -o json | jq -r --arg dpid "${OLD_DP_ID}" '.items[] | select(.metadata.name | contains($dpid)) | "\(.metadata.namespace) \(.metadata.name)"' | while read ns name; do
            echo "  Deleting pod: ${ns}/${name}"
            kubectl delete pod "${name}" -n "${ns}" --grace-period=30 || true
        done
    fi
fi

# Check for Helm releases
echo ""
echo "🔍 Checking for old TIBCO Helm releases..."
OLD_RELEASES=$(helm list -A -o json | jq -r --arg dpid "${OLD_DP_ID}" '.[] | select(.name | contains($dpid)) | "\(.namespace)/\(.name)"')

if [[ -n "${OLD_RELEASES}" ]]; then
    echo ""
    echo "⚠️  WARNING: Old TIBCO Helm releases found:"
    echo "${OLD_RELEASES}" | while read release; do
        echo "  • ${release}"
    done
    echo ""
    echo "Please uninstall old TIBCO releases manually:"
    echo "${OLD_RELEASES}" | while read release; do
        ns=$(echo "${release}" | cut -d'/' -f1)
        name=$(echo "${release}" | cut -d'/' -f2)
        echo "  helm uninstall ${name} -n ${ns}"
    done
    echo ""
    read -p "Continue with ingress class removal anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Cancelled"
        exit 1
    fi
fi

# Confirm removal
echo ""
echo "⚠️  This will remove the ingress class: ${OLD_INGRESSCLASS}"
echo ""
read -p "Proceed with removal? (y/n) " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Cancelled"
    exit 1
fi

# Create backup
BACKUP_DIR="./backups/$(date +%Y%m%d-%H%M%S)-cleanup-old-dp"
mkdir -p "${BACKUP_DIR}"
echo ""
echo "📦 Creating backup in ${BACKUP_DIR}..."
kubectl get ingressclass "${OLD_INGRESSCLASS}" -o yaml > "${BACKUP_DIR}/old-ingressclass.yaml"
echo "✅ Backup created"

# Remove the ingress class
echo ""
echo "🗑️  Removing old ingress class..."
kubectl delete ingressclass "${OLD_INGRESSCLASS}"

echo ""
echo "=========================================="
echo "✅ Cleanup Complete"
echo "=========================================="
echo ""
echo "📋 Summary:"
echo "  ✅ Removed ingress class: ${OLD_INGRESSCLASS}"
echo "  ✅ Backup saved: ${BACKUP_DIR}/old-ingressclass.yaml"
echo ""
echo "📊 Remaining ingress classes:"
kubectl get ingressclass
echo ""
echo "ℹ️  The new TIBCO Platform v1.15.0 Data Plane will use:"
echo "  • Ingress Controller: Traefik (shared)"
echo "  • DP ID: ${TP_DP_INSTANCE_ID} (clean, human-readable)"
echo "  • Namespace: ${TP_DP_NAMESPACE}"
echo ""
