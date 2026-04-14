#!/usr/bin/env bash

################################################################################
# Master Installation Script
# 
# Purpose: Execute all prerequisite and installation steps in sequence
# 
# Usage: 
#   ./install-all.sh              # Fresh installation
#   ./install-all.sh --clean      # Clean databases first, then install
################################################################################

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLEAN_MODE=false

# Parse arguments
if [ "$1" == "--clean" ]; then
    CLEAN_MODE=true
fi

echo "=========================================="
echo "TIBCO Platform Control Plane"
echo "Complete Installation Script"
echo "=========================================="
echo ""

if [ "$CLEAN_MODE" == "true" ]; then
    echo "⚠️  CLEAN MODE: Will drop existing databases"
    echo ""
fi

# Step 1: Create namespace and RBAC
echo "=========================================="
echo "Step 1: Namespace and RBAC"
echo "=========================================="
"${SCRIPT_DIR}/03a-create-namespace-and-rbac.sh"
echo ""
echo "Press Enter to continue or Ctrl+C to abort..."
read

# Step 2: Install PostgreSQL
echo "=========================================="
echo "Step 2: PostgreSQL"
echo "=========================================="
"${SCRIPT_DIR}/03b-install-postgresql.sh"
echo ""
echo "Press Enter to continue or Ctrl+C to abort..."
read

# Step 3: Install MailDev
echo "=========================================="
echo "Step 3: MailDev Email Server"
echo "=========================================="
"${SCRIPT_DIR}/03c-install-maildev.sh"
echo ""
echo "Press Enter to continue or Ctrl+C to abort..."
read

# Step 4: Create Secrets
echo "=========================================="
echo "Step 4: Create Secrets"
echo "=========================================="
"${SCRIPT_DIR}/03d-create-secrets.sh"
echo ""
echo "Press Enter to continue or Ctrl+C to abort..."
read

# Step 5: Configure CoreDNS
echo "=========================================="
echo "Step 5: Configure CoreDNS"
echo "=========================================="
"${SCRIPT_DIR}/03a-configure-coredns.sh"
echo ""
echo "Press Enter to continue or Ctrl+C to abort..."
read

# Optional: Clean databases
if [ "$CLEAN_MODE" == "true" ]; then
    echo "=========================================="
    echo "Step 6 (Optional): Clean Databases"
    echo "=========================================="
    "${SCRIPT_DIR}/04a-cleanup-databases.sh"
    echo ""
    echo "Press Enter to continue or Ctrl+C to abort..."
    read
fi

# Step 6: Install Control Plane
echo "=========================================="
echo "Step 7: Install Control Plane"
echo "=========================================="
"${SCRIPT_DIR}/05-install-controlplane.sh"

echo ""
echo "=========================================="
echo "✅ Installation Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "  1. Wait for all pods to be Running (10-15 minutes)"
echo "     kubectl get pods -n cp1-ns -w"
echo ""
echo "  2. Retrieve admin password:"
echo "     ./06-get-admin-password.sh"
echo ""
echo "  3. Access admin console:"
echo "     https://admin.dp1.atsnl-emea.azure.dataplanes.pro"
echo ""
echo "=========================================="
