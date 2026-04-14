#!/usr/bin/env bash

################################################################################
# Step 3: Install MailDev Email Server
# 
# Purpose: Install MailDev for email testing in tibco-ext namespace
################################################################################

set -e

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/aks-env-variables-dp1.sh"

MAILDEV_MANIFEST="${SCRIPT_DIR}/values/maildev-deployment.yaml"

echo "=========================================="
echo "Step 3: MailDev Email Server Installation"
echo "=========================================="
echo ""
echo "Configuration:"
echo "  Namespace: tibco-ext"
echo "  Manifest: ${MAILDEV_MANIFEST}"
echo "  Web UI: https://mail.${TP_BASE_DNS_DOMAIN}"
echo "  SMTP: development-mailserver.tibco-ext.svc.cluster.local:1025"
echo ""

# Check if MailDev is already installed
if kubectl get deployment maildev -n tibco-ext &>/dev/null; then
    echo "✅ MailDev already installed"
    kubectl get pods -n tibco-ext -l app=development-mailserver
    exit 0
fi

# Deploy MailDev
echo "Deploying MailDev..."
kubectl apply -f "${MAILDEV_MANIFEST}"

# Wait for deployment
echo ""
echo "Waiting for MailDev to be ready..."
kubectl wait --for=condition=available --timeout=120s \
  deployment/maildev -n tibco-ext

echo ""
echo "✅ MailDev deployed successfully"

# Verify installation
echo ""
echo "Verifying MailDev deployment..."
kubectl get deployment,service,ingress -n tibco-ext -l app=development-mailserver

echo ""
echo "=========================================="
echo "MailDev Access Information:"
echo "=========================================="
echo "  Web UI: https://mail.${TP_BASE_DNS_DOMAIN}"
echo "  SMTP Server: development-mailserver.tibco-ext.svc.cluster.local"
echo "  SMTP Port: 1025"
echo ""
echo "✅ MailDev installation complete"
echo "=========================================="
