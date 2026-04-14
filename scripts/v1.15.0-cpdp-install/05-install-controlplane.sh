#!/usr/bin/env bash

################################################################################
# Step 5: Install TIBCO Platform Control Plane
# 
# Purpose: Deploy tibco-cp-base Helm chart with corrected v1.15.0 values
################################################################################

set -e

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/aks-env-variables-dp1.sh"

VALUES_FILE="${SCRIPT_DIR}/values/cp1-values.yaml"

echo "=========================================="
echo "Step 5: Control Plane Installation"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Release Name: tibco-cp-base"
echo "  Namespace: ${CP_NAMESPACE}"
echo "  Chart: tibco-platform/tibco-cp-base"
echo "  Version: 1.15.0"
echo "  Values File: ${VALUES_FILE}"
echo ""

# Validate prerequisites
echo "Validating prerequisites..."
echo ""

# Check namespace
if ! kubectl get namespace ${CP_NAMESPACE} &>/dev/null; then
    echo "❌ Namespace ${CP_NAMESPACE} not found"
    echo "Run: ./03a-create-namespace-and-rbac.sh"
    exit 1
fi
echo "✅ Namespace ${CP_NAMESPACE} exists"

# Check PostgreSQL
if ! kubectl get statefulset postgresql -n tibco-ext &>/dev/null; then
    echo "❌ PostgreSQL not found in tibco-ext"
    echo "Run: ./03b-install-postgresql.sh"
    exit 1
fi
echo "✅ PostgreSQL running in tibco-ext"

# Check MailDev
if ! kubectl get deployment maildev -n tibco-ext &>/dev/null; then
    echo "❌ MailDev not found in tibco-ext"
    echo "Run: ./03c-install-maildev.sh"
    exit 1
fi
echo "✅ MailDev running in tibco-ext"

# Check secrets
MISSING_SECRETS=0
for SECRET in session-keys cporch-encryption-secret postgresql tibco-container-registry-credentials; do
    if ! kubectl get secret ${SECRET} -n ${CP_NAMESPACE} &>/dev/null; then
        echo "❌ Secret ${SECRET} not found in ${CP_NAMESPACE}"
        MISSING_SECRETS=1
    else
        echo "✅ Secret ${SECRET} exists"
    fi
done

if [ ${MISSING_SECRETS} -eq 1 ]; then
    echo ""
    echo "Run: ./03d-create-secrets.sh"
    exit 1
fi

# Check values file
if [ ! -f "${VALUES_FILE}" ]; then
    echo "❌ Values file not found: ${VALUES_FILE}"
    exit 1
fi
echo "✅ Values file found"

# Add TIBCO Helm repository
echo ""
echo "Adding TIBCO Platform Helm repository..."
helm repo add tibco-platform https://tibcosoftware.github.io/tp-helm-charts 2>/dev/null || true
helm repo update

# Check if already installed
if helm list -n ${CP_NAMESPACE} | grep -q tibco-cp-base; then
    echo ""
    echo "⚠️  tibco-cp-base already installed"
    read -p "Upgrade existing installation? (yes/no): " UPGRADE
    if [ "$UPGRADE" != "yes" ]; then
        echo "Aborted."
        exit 0
    fi
    ACTION="upgrade"
else
    ACTION="install"
fi

# Install/Upgrade Control Plane
echo ""
echo "=========================================="
echo "${ACTION^}ing TIBCO Platform Control Plane..."
echo "This may take 15-20 minutes"
echo "=========================================="
echo ""

helm upgrade --install --wait --timeout 20m \
  -n ${CP_NAMESPACE} \
  tibco-cp-base \
  tibco-platform/tibco-cp-base \
  --version "1.15.0" \
  --values "${VALUES_FILE}"

echo ""
echo "✅ Control Plane ${ACTION} completed"

# Verify installation
echo ""
echo "Verifying Control Plane deployment..."
kubectl get pods -n ${CP_NAMESPACE}

echo ""
echo "=========================================="
echo "Control Plane Installation Summary"
echo "=========================================="
echo ""
echo "  Namespace: ${CP_NAMESPACE}"
echo "  Release: tibco-cp-base"
echo "  Version: 1.15.0"
echo ""
echo "Next steps:"
echo "  1. Wait for all pods to be Running (can take 10-15 minutes)"
echo "  2. Retrieve admin password: ./06-get-admin-password.sh"
echo "  3. Access admin console: https://admin.${TP_BASE_DNS_DOMAIN}"
echo ""
echo "=========================================="
