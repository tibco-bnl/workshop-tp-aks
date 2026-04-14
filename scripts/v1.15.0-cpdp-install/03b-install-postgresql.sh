#!/usr/bin/env bash

################################################################################
# Step 2: Install PostgreSQL
# 
# Purpose: Install PostgreSQL in tibco-ext namespace using Bitnami Helm chart
################################################################################

set -e

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/aks-env-variables-dp1.sh"

VALUES_FILE="${SCRIPT_DIR}/values/postgresql-values.yaml"

echo "=========================================="
echo "Step 2: PostgreSQL Installation"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Namespace: tibco-ext"
echo "  Release Name: postgresql"
echo "  Chart: bitnami/postgresql ^16.0.0"
echo "  Values File: ${VALUES_FILE}"
echo ""

# Create tibco-ext namespace if it doesn't exist
echo "Creating tibco-ext namespace..."
kubectl create namespace tibco-ext --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Namespace tibco-ext created/verified"

# Create container registry secret in tibco-ext namespace
echo ""
echo "Creating container registry secret in tibco-ext..."
kubectl create secret docker-registry tibco-container-registry-credentials \
  --namespace tibco-ext \
  --docker-server="${TP_CONTAINER_REGISTRY}" \
  --docker-username="${TP_CONTAINER_REGISTRY_USERNAME}" \
  --docker-password="${TP_CONTAINER_REGISTRY_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "✅ Container registry secret created in tibco-ext"

# Check if PostgreSQL is already installed
if kubectl get statefulset postgresql -n tibco-ext &>/dev/null; then
    echo ""
    echo "⚠️  PostgreSQL already installed in tibco-ext namespace"
    echo "Run: helm uninstall postgresql -n tibco-ext"
    echo "Then: kubectl delete pvc data-postgresql-0 -n tibco-ext"
    echo "To reinstall from scratch"
    exit 0
fi

# Add Bitnami Helm repo
echo ""
echo "Adding Bitnami Helm repository..."
helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
helm repo update

# Install PostgreSQL
echo ""
echo "Installing PostgreSQL (this may take 5-10 minutes)..."
helm upgrade --install --wait --timeout 15m \
  --create-namespace \
  -n tibco-ext \
  postgresql \
  bitnami/postgresql \
  --version "^16.0.0" \
  --values "${VALUES_FILE}"

echo ""
echo "✅ PostgreSQL installed successfully"

# Verify installation
echo ""
echo "Verifying PostgreSQL deployment..."
kubectl get statefulset postgresql -n tibco-ext
kubectl get pods -n tibco-ext -l app.kubernetes.io/name=postgresql

echo ""
echo "=========================================="
echo "PostgreSQL Connection Details:"
echo "=========================================="
echo "  Host: postgresql.tibco-ext.svc.cluster.local"
echo "  Port: 5432"
echo "  Database: postgres"
echo "  User: postgres"
echo "  Password: postgres"
echo ""
echo "✅ PostgreSQL installation complete"
echo "=========================================="
