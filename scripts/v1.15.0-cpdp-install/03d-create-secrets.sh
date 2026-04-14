#!/usr/bin/env bash

################################################################################
# Step 4: Create Required Secrets
# 
# Purpose: Create session keys, encryption secret, and PostgreSQL secret
################################################################################

set -e

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/aks-env-variables-dp1.sh"

echo "=========================================="
echo "Step 4: Creating Required Secrets"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  CP Namespace: ${CP_NAMESPACE}"
echo ""

# 1. Session Keys Secret
echo "Creating session-keys secret..."
if kubectl get secret session-keys -n ${CP_NAMESPACE} &>/dev/null; then
    echo "⚠️  session-keys secret already exists, skipping..."
else
    # Generate random session keys
    TSC_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)
    DOMAIN_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)
    
    kubectl create secret generic session-keys -n ${CP_NAMESPACE} \
      --from-literal=TSC_SESSION_KEY=${TSC_SESSION_KEY} \
      --from-literal=DOMAIN_SESSION_KEY=${DOMAIN_SESSION_KEY} \
      --from-literal=SESSION_KEY=${TSC_SESSION_KEY} \
      --from-literal=SESSION_IV=${DOMAIN_SESSION_KEY}
    
    echo "✅ session-keys secret created"
fi

# 2. CP Orchestration Encryption Secret
echo ""
echo "Creating cporch-encryption-secret..."
if kubectl get secret cporch-encryption-secret -n ${CP_NAMESPACE} &>/dev/null; then
    echo "⚠️  cporch-encryption-secret already exists, skipping..."
else
    # Generate encryption secret
    CP_ENCRYPTION_SECRET=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c44)
    
    kubectl create secret generic cporch-encryption-secret -n ${CP_NAMESPACE} \
      --from-literal=CP_ENCRYPTION_SECRET=${CP_ENCRYPTION_SECRET} \
      --from-literal=CPORCH_ENCRYPTION_KEY=${CP_ENCRYPTION_SECRET}
    
    echo "✅ cporch-encryption-secret created"
fi

# 3. PostgreSQL Secret (reference to tibco-ext)
echo ""
echo "Creating postgresql secret reference..."
if kubectl get secret postgresql -n ${CP_NAMESPACE} &>/dev/null; then
    echo "⚠️  postgresql secret already exists, skipping..."
else
    kubectl create secret generic postgresql -n ${CP_NAMESPACE} \
      --from-literal=postgres-password="${TP_POSTGRES_PASSWORD}" \
      --from-literal=password="${TP_POSTGRES_PASSWORD}"
    
    echo "✅ postgresql secret created"
fi

# Verify secrets
echo ""
echo "Verifying secrets..."
kubectl get secrets -n ${CP_NAMESPACE} | grep -E "session-keys|cporch-encryption|postgresql|tibco-container"

echo ""
echo "=========================================="
echo "✅ All secrets created successfully"
echo "=========================================="
