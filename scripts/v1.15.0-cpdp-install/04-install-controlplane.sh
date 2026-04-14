#!/bin/bash
# Install TIBCO Platform Control Plane v1.15.0 with DNS Simplification

set -e

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-environment-v1.15.sh"

echo "=========================================="
echo "Installing TIBCO Platform Control Plane v1.15.0"
echo "=========================================="

# Validate prerequisites
validate_prerequisites || exit 1

# Create backup
create_backup

# Verify prerequisites created by 03-setup-cp-prerequisites.sh
echo ""
echo "🔍 Verifying prerequisites..."

# Check namespace exists
if ! kubectl get namespace ${TP_CP_NAMESPACE} &>/dev/null; then
    echo "❌ ERROR: Namespace ${TP_CP_NAMESPACE} not found"
    echo "   Please run: ./03-setup-cp-prerequisites.sh"
    exit 1
fi

# Check required secrets exist
REQUIRED_SECRETS=(
    "tibco-container-registry-credentials"
    "session-keys"
    "cporch-encryption-secret"
)

for secret in "${REQUIRED_SECRETS[@]}"; do
    if ! kubectl get secret "${secret}" -n ${TP_CP_NAMESPACE} &>/dev/null; then
        echo "❌ ERROR: Secret ${secret} not found in ${TP_CP_NAMESPACE}"
        echo "   Please run: ./03-setup-cp-prerequisites.sh"
        exit 1
    fi
done

# Check PostgreSQL in tibco-ext namespace
if ! kubectl get statefulset postgresql -n tibco-ext &>/dev/null; then
    echo "❌ ERROR: PostgreSQL not found in tibco-ext namespace"
    echo "   Please run: ./03-setup-cp-prerequisites.sh"
    exit 1
fi

# Check MailDev in tibco-ext namespace (optional but recommended)
if ! kubectl get deployment maildev -n tibco-ext &>/dev/null; then
    echo "⚠️  WARNING: MailDev not found in tibco-ext namespace"
    echo "   Email functionality may not work. Consider running: ./03-setup-cp-prerequisites.sh"
fi

echo "✅ All prerequisites verified"

# Check if values file exists
if [[ ! -f "${SCRIPT_DIR}/values/cp1-values.yaml" ]]; then
    echo "❌ ERROR: Values file not found: ${SCRIPT_DIR}/values/cp1-values.yaml"
    exit 1
fi

echo ""
echo "📋 Using values file: ${SCRIPT_DIR}/values/cp1-values.yaml"
echo ""
echo "Configuration Summary:"
echo "  CP Instance: ${TP_CP_INSTANCE_ID}"
echo "  Namespace: ${TP_CP_NAMESPACE}"
echo "  Admin Domain: admin.${TP_BASE_DNS_DOMAIN}"
echo "  Tunnel Domain: tunnel.${TP_BASE_DNS_DOMAIN}"
echo "  PostgreSQL: postgresql.tibco-ext.svc.cluster.local:5432"
echo "  SMTP: development-mailserver.tibco-ext.svc.cluster.local:1025"
echo "  Ingress Class: ${INGRESS_CLASS}"
echo ""

# Use the cp1-values.yaml file (uses PostgreSQL in tibco-ext namespace)
echo ""
echo "📝 Using values file: values/cp1-values.yaml"
cp "${SCRIPT_DIR}/values/cp1-values.yaml" /tmp/cp-values-v1.15.yaml

echo "✅ Values file prepared"

# Add TIBCO Helm repository
echo ""
echo "📦 Adding TIBCO Helm repository..."
helm repo add tibco-platform ${TP_HELM_REPO} || helm repo add tibco-platform ${TP_HELM_REPO}
helm repo update

# Install Control Plane
echo ""
echo "🚀 Installing TIBCO Platform Control Plane v${TP_VERSION}..."
echo "This may take 10-15 minutes..."

helm install tibco-cp tibco-platform/tibco-platform-cp \
  --namespace ${TP_CP_NAMESPACE} \
  --values /tmp/cp-values-v1.15.yaml \
  --version ${TP_CHART_VERSION} \
  --timeout 20m \
  --wait

# Monitor deployment
echo ""
echo "📊 Monitoring deployment progress..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/component=cp-core \
  -n ${TP_CP_NAMESPACE} \
  --timeout=600s || true

# Display status
echo ""
echo "=========================================="
echo "✅ Control Plane Installation Complete"
echo "=========================================="
echo ""
echo "📊 Control Plane Status:"
kubectl get pods -n ${TP_CP_NAMESPACE}

echo ""
echo "🌐 Access URLs (v1.15.0 Simplified DNS):"
echo "Admin UI: https://admin.${TP_BASE_DNS_DOMAIN}"
echo "Tunnel: https://tunnel.${TP_BASE_DNS_DOMAIN}"

echo ""
echo "🔍 To check logs:"
echo "kubectl logs -n ${TP_CP_NAMESPACE} -l app.kubernetes.io/component=cp-core -f"

echo ""
echo "📋 Next Steps:"
echo "1. Access Control Plane UI: https://admin.${TP_BASE_DNS_DOMAIN}"
echo "2. Complete initial setup wizard"
echo "3. Create Data Plane registration token"
echo "4. Run: ./04-install-dataplane.sh"

# Cleanup
rm -f /tmp/cp-values-v1.15.yaml
