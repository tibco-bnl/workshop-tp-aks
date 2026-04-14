#!/usr/bin/env bash

################################################################################
# Step 1: Create Namespace and RBAC
# 
# Purpose: Create CP namespace, service account, and label ingress namespace
################################################################################

set -e

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/aks-env-variables-dp1.sh"

echo "=========================================="
echo "Step 1: Namespace and RBAC Setup"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  CP Instance ID: ${CP_INSTANCE_ID}"
echo "  CP Namespace: ${CP_NAMESPACE}"
echo "  Service Account: ${CP_SERVICE_ACCOUNT}"
echo ""

# Create namespace
echo "Creating namespace ${CP_NAMESPACE}..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${CP_NAMESPACE}
  labels:
    platform.tibco.com/controlplane-instance-id: ${CP_INSTANCE_ID}
    networking.platform.tibco.com/non-cp-ns: enable
EOF

echo "✅ Namespace ${CP_NAMESPACE} created"

# Label ingress-system namespace
echo ""
echo "Labeling ingress-system namespace..."
kubectl label namespace ingress-system \
  networking.platform.tibco.com/non-cp-ns=enable \
  --overwrite=true

echo "✅ Ingress namespace labeled"

# Create service account
echo ""
echo "Creating service account ${CP_SERVICE_ACCOUNT}..."
kubectl create serviceaccount ${CP_SERVICE_ACCOUNT} -n ${CP_NAMESPACE} \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Service account ${CP_SERVICE_ACCOUNT} created"

# Create container registry secret in CP namespace
echo ""
echo "Creating container registry secret in ${CP_NAMESPACE}..."
kubectl create secret docker-registry tibco-container-registry-credentials \
  --namespace ${CP_NAMESPACE} \
  --docker-server="${TP_CONTAINER_REGISTRY}" \
  --docker-username="${TP_CONTAINER_REGISTRY_USERNAME}" \
  --docker-password="${TP_CONTAINER_REGISTRY_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Container registry secret created in ${CP_NAMESPACE}"

echo ""
echo "=========================================="
echo "✅ Namespace and RBAC setup complete"
echo "=========================================="
