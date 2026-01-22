#!/bin/bash

################################################################################
# TIBCO Platform on AKS - Environment Variables Configuration
# 
# This script sets all required environment variables for deploying
# TIBCO Platform Control Plane and Data Plane on Azure Kubernetes Service (AKS)
#
# Usage:
#   1. Edit the values below according to your environment
#   2. Source this file: source aks-env-variables.sh
#   3. Verify variables: env | grep TP_
#
# Last Updated: January 22, 2026
################################################################################

echo "Setting up TIBCO Platform environment variables for AKS..."

################################################################################
# Azure Subscription and Region Configuration
################################################################################

# Azure subscription and tenant
export TP_SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null || echo "")
export TP_TENANT_ID=$(az account show --query tenantId -o tsv 2>/dev/null || echo "")
export TP_AZURE_REGION="eastus"  # Change to your preferred Azure region

if [ -z "$TP_SUBSCRIPTION_ID" ]; then
  echo "⚠️  Warning: Azure CLI not authenticated. Please run 'az login' first."
fi

################################################################################
# AKS Cluster Configuration
################################################################################

# Resource Group and Cluster
export TP_RESOURCE_GROUP="tibco-platform-rg"  # Azure resource group name
export TP_CLUSTER_NAME="tibco-aks-cluster"    # AKS cluster name
export TP_KUBERNETES_VERSION="1.33"            # Kubernetes version (1.32 or above)
export KUBECONFIG=$(pwd)/${TP_CLUSTER_NAME}.yaml  # Kubeconfig file path

# Network Configuration
export TP_VNET_NAME="${TP_CLUSTER_NAME}-vnet"
export TP_VNET_CIDR="10.4.0.0/16"              # VNet CIDR block
export TP_SERVICE_CIDR="10.0.0.0/16"           # Kubernetes service CIDR
export TP_AKS_SUBNET_CIDR="10.4.0.0/20"        # AKS subnet CIDR
export TP_APISERVER_SUBNET_CIDR="10.4.19.0/28" # API server subnet CIDR (if using private cluster)

# Network Policy
export TP_NETWORK_POLICY=""  # Options: "" (disable), "calico", "azure"

################################################################################
# Control Plane Configuration
################################################################################

# Control Plane Instance Details
export CP_INSTANCE_ID="cp1"  # ⚠️ CRITICAL: NO HYPHENS! Used as PostgreSQL database prefix
export CP_NAMESPACE="${CP_INSTANCE_ID}-ns"
export CP_CHART_VERSION="1.3.0"  # TIBCO Control Plane chart version

# Domain Configuration for Control Plane
export TP_TOP_LEVEL_DOMAIN="azure.example.com"    # Your top-level domain
export TP_SANDBOX="platform"                       # Sandbox/environment name
export CP_MY_DNS_DOMAIN="${CP_INSTANCE_ID}-my.${TP_SANDBOX}.${TP_TOP_LEVEL_DOMAIN}"
export CP_TUNNEL_DNS_DOMAIN="${CP_INSTANCE_ID}-tunnel.${TP_SANDBOX}.${TP_TOP_LEVEL_DOMAIN}"

# Examples:
# CP_MY_DNS_DOMAIN = cp1-my.platform.azure.example.com
# CP_TUNNEL_DNS_DOMAIN = cp1-tunnel.platform.azure.example.com

################################################################################
# Data Plane Configuration
################################################################################

# Data Plane Instance Details
export DP_INSTANCE_ID="dp1"
export DP_NAMESPACE="${DP_INSTANCE_ID}-ns"

# Domain Configuration for Data Plane
export TP_DP_SANDBOX="dp1"
export TP_MAIN_INGRESS_SANDBOX_SUBDOMAIN="services"
export TP_DOMAIN="${TP_MAIN_INGRESS_SANDBOX_SUBDOMAIN}.${TP_DP_SANDBOX}.${TP_TOP_LEVEL_DOMAIN}"

# Optional: Separate domain for user apps (uncomment if needed)
# export TP_SECONDARY_INGRESS_SANDBOX_SUBDOMAIN="apps"
# export TP_SECONDARY_DOMAIN="${TP_SECONDARY_INGRESS_SANDBOX_SUBDOMAIN}.${TP_DP_SANDBOX}.${TP_TOP_LEVEL_DOMAIN}"

# Examples:
# TP_DOMAIN = services.dp1.azure.example.com
# TP_SECONDARY_DOMAIN = apps.dp1.azure.example.com

################################################################################
# Storage Configuration
################################################################################

# Azure Disk Storage (for EMS, PostgreSQL, Developer Hub)
export TP_DISK_ENABLED="true"
export TP_DISK_STORAGE_CLASS="azure-disk-sc"

# Azure Files Storage (for BWCE, shared storage)
export TP_FILE_ENABLED="true"
export TP_FILE_STORAGE_CLASS="azure-files-sc"

# Storage Account for Azure Files
export TP_STORAGE_ACCOUNT_NAME="tibcostorageacct"  # Must be globally unique, 3-24 chars, lowercase alphanumeric
export TP_STORAGE_ACCOUNT_RESOURCE_GROUP="${TP_RESOURCE_GROUP}"

################################################################################
# Ingress Controller Configuration
################################################################################

# Primary Ingress Controller (Traefik recommended, NGINX deprecated)
export TP_INGRESS_CLASS="traefik"  # Options: "traefik" (recommended), "nginx" (deprecated)
export TP_MAIN_INGRESS_CONTROLLER="traefik"

# Secondary Ingress Controller for User Apps (optional)
# export TP_SECONDARY_INGRESS_CLASS="kong"  # Only for BWCE and Flogo apps

################################################################################
# DNS Configuration
################################################################################

# Azure DNS Zone
export TP_DNS_RESOURCE_GROUP="${TP_RESOURCE_GROUP}"  # Resource group containing DNS zone
export TP_DNS_ZONE_NAME="${TP_TOP_LEVEL_DOMAIN}"

# External DNS Configuration (for automatic DNS record creation)
export TP_EXTERNAL_DNS_ENABLED="true"

################################################################################
# PostgreSQL Database Configuration (Control Plane)
################################################################################

# Database Connection Details
export TP_POSTGRES_HOST="postgresql.tibco-ext.svc.cluster.local"  # PostgreSQL hostname
export TP_POSTGRES_PORT="5432"
export TP_POSTGRES_DATABASE="postgres"
export TP_POSTGRES_USERNAME="postgres"
export TP_POSTGRES_PASSWORD="postgres"  # ⚠️ Change in production!

# For Azure Database for PostgreSQL Flexible Server, use:
# export TP_POSTGRES_HOST="myserver.postgres.database.azure.com"
# export TP_POSTGRES_USERNAME="adminuser"
# export TP_POSTGRES_PASSWORD="<your-secure-password>"

# SSL Configuration (required for Azure PostgreSQL)
export TP_POSTGRES_SSL_MODE="disable"  # Options: "disable", "require", "verify-ca", "verify-full"
# For Azure PostgreSQL, set to "require" and provide SSL certificate

################################################################################
# Container Registry Configuration
################################################################################

# TIBCO Container Registry
export TP_CONTAINER_REGISTRY="csgprdusw2reposaas.jfrog.io"
export TP_CONTAINER_REGISTRY_USERNAME="<your-username>"  # Provided by TIBCO
export TP_CONTAINER_REGISTRY_PASSWORD="<your-password>"  # Provided by TIBCO
export TP_CONTAINER_REGISTRY_EMAIL="<your-email>"

################################################################################
# Helm Chart Repository
################################################################################

export TP_TIBCO_HELM_CHART_REPO="https://tibcosoftware.github.io/tp-helm-charts"

################################################################################
# Observability Configuration (Optional)
################################################################################

# Elastic Stack for Logging
export TP_ES_RELEASE_NAME="dp-config-es"
export TP_ES_VERSION="8.11.0"

# Prometheus & Grafana
export TP_PROMETHEUS_ENABLED="true"
export TP_GRAFANA_ENABLED="true"

################################################################################
# Email/SMTP Configuration (Optional)
################################################################################

# Option 1: MailDev (for testing/workshops)
export TP_MAILDEV_ENABLED="true"

# Option 2: Real SMTP Server (for production)
# export TP_SMTP_HOST="smtp.sendgrid.net"
# export TP_SMTP_PORT="587"
# export TP_SMTP_USERNAME="apikey"
# export TP_SMTP_PASSWORD="<your-sendgrid-api-key>"
# export TP_SMTP_FROM="noreply@example.com"

################################################################################
# Network Policy Configuration
################################################################################

export TP_ENABLE_NETWORK_POLICY="false"  # Set to "true" for production

################################################################################
# Log Server Configuration (Optional)
################################################################################

export TP_LOGSERVER_ENDPOINT=""
export TP_LOGSERVER_INDEX=""
export TP_LOGSERVER_USERNAME=""
export TP_LOGSERVER_PASSWORD=""

################################################################################
# Certificate Configuration
################################################################################

# Certificate paths (update with actual certificate locations)
export TP_TLS_CERT_MY="${HOME}/certs/cp-my-cert.pem"
export TP_TLS_KEY_MY="${HOME}/certs/cp-my-key.pem"
export TP_TLS_CERT_TUNNEL="${HOME}/certs/cp-tunnel-cert.pem"
export TP_TLS_KEY_TUNNEL="${HOME}/certs/cp-tunnel-key.pem"

################################################################################
# Azure-Specific Configuration
################################################################################

# Azure Managed Identity (if using)
export TP_USE_MANAGED_IDENTITY="false"
export TP_MANAGED_IDENTITY_CLIENT_ID=""

# Azure Key Vault (for secrets management)
export TP_KEY_VAULT_NAME=""
export TP_KEY_VAULT_RESOURCE_GROUP=""

################################################################################
# Validation and Display
################################################################################

echo ""
echo "✅ Environment variables set successfully!"
echo ""
echo "Key Configuration Summary:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Azure Region:              ${TP_AZURE_REGION}"
echo "Resource Group:            ${TP_RESOURCE_GROUP}"
echo "AKS Cluster:               ${TP_CLUSTER_NAME}"
echo "Kubernetes Version:        ${TP_KUBERNETES_VERSION}"
echo ""
echo "Control Plane:"
echo "  Instance ID:             ${CP_INSTANCE_ID}"
echo "  Namespace:               ${CP_NAMESPACE}"
echo "  MY Domain:               ${CP_MY_DNS_DOMAIN}"
echo "  Tunnel Domain:           ${CP_TUNNEL_DNS_DOMAIN}"
echo ""
echo "Data Plane:"
echo "  Instance ID:             ${DP_INSTANCE_ID}"
echo "  Namespace:               ${DP_NAMESPACE}"
echo "  Domain:                  ${TP_DOMAIN}"
echo ""
echo "Storage:"
echo "  Disk Storage Class:      ${TP_DISK_STORAGE_CLASS}"
echo "  Files Storage Class:     ${TP_FILE_STORAGE_CLASS}"
echo "  Storage Account:         ${TP_STORAGE_ACCOUNT_NAME}"
echo ""
echo "Ingress:"
echo "  Ingress Class:           ${TP_INGRESS_CLASS}"
echo ""
echo "PostgreSQL:"
echo "  Host:                    ${TP_POSTGRES_HOST}"
echo "  Port:                    ${TP_POSTGRES_PORT}"
echo "  Database:                ${TP_POSTGRES_DATABASE}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "⚠️  Important Reminders:"
echo "  1. Update container registry credentials before deployment"
echo "  2. Ensure CP_INSTANCE_ID contains NO HYPHENS (current: ${CP_INSTANCE_ID})"
echo "  3. Update certificate paths before Control Plane deployment"
echo "  4. For production, use Azure Database for PostgreSQL Flexible Server"
echo ""
echo "To verify all TP_ variables: env | grep TP_"
echo "To verify all CP_ variables: env | grep CP_"
echo "To verify all DP_ variables: env | grep DP_"
echo ""
