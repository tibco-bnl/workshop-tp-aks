#!/usr/bin/env bash

################################################################################
# Retrieve Auto-Generated Admin Password
# 
# Purpose: Get the auto-generated admin password from v1.15 deployment
#
# Background:
# - v1.15 auto-generates the admin password during deployment
# - Password is stored in secret: tp-cp-web-server
# - Key: TSC_ADMIN_PASSWORD
#
# Usage: ./06-get-admin-password.sh
################################################################################

set -e

CP_NAMESPACE="cp1-ns"
SECRET_NAME="tp-cp-web-server"
SECRET_KEY="TSC_ADMIN_PASSWORD"

echo "========================================="
echo "Retrieve Admin Password"
echo "========================================="
echo ""

# Check if secret exists
if ! kubectl get secret ${SECRET_NAME} -n ${CP_NAMESPACE} &>/dev/null; then
  echo "❌ Error: Secret '${SECRET_NAME}' not found in namespace '${CP_NAMESPACE}'"
  echo ""
  echo "Possible causes:"
  echo "1. Control Plane deployment has not completed yet"
  echo "2. Control Plane deployment failed"
  echo "3. Deployment is using a different namespace"
  echo ""
  echo "Check deployment status:"
  echo "  kubectl get pods -n ${CP_NAMESPACE}"
  exit 1
fi

# Extract password
ADMIN_PASSWORD=$(kubectl get secret ${SECRET_NAME} -n ${CP_NAMESPACE} \
  -o jsonpath="{.data.${SECRET_KEY}}" | base64 --decode)

if [ -z "$ADMIN_PASSWORD" ]; then
  echo "❌ Error: Password key '${SECRET_KEY}' not found in secret"
  echo ""
  echo "Debugging info:"
  kubectl get secret ${SECRET_NAME} -n ${CP_NAMESPACE} -o yaml
  exit 1
fi

echo "✅ Admin password retrieved successfully"
echo ""
echo "========================================="
echo "  Control Plane Login Credentials"
echo "========================================="
echo ""
echo "  URL:      https://admin.dp1.atsnl-emea.azure.dataplanes.pro"
echo "  Username: admin@tibco.com"
echo "  Password: ${ADMIN_PASSWORD}"
echo ""
echo "========================================="
echo ""
echo "💡 Tip: You may need to accept SSL certificate warnings during login"
echo ""
