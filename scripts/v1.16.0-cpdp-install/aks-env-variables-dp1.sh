#!/bin/bash

################################################################################
# TIBCO Platform on AKS - Environment Variables Configuration
# 
# Cluster: dp1-aks-aauk-kul
# Environment: ATSBNL EMEA Presales
# TIBCO Platform Version: v1.16.0
# Ingress Controller: Traefik
# Last Updated: April 10, 2026
#
# Usage:
#   1. Edit the container registry credentials below
#   2. Source this file: source aks-env-variables-dp1.sh
#   3. Verify variables: env | grep TP_
#
################################################################################

echo "Setting up TIBCO Platform v1.16.0 environment variables for dp1-aks-aauk-kul cluster..."

################################################################################
# Azure Subscription and Region Configuration
################################################################################

# Azure subscription and tenant (automatically retrieved from current az login)
export TP_SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null || echo "")
export TP_SUBSCRIPTION_NAME=$(az account show --query name -o tsv 2>/dev/null || echo "")
export TP_TENANT_ID=$(az account show --query tenantId -o tsv 2>/dev/null || echo "")
export TP_AZURE_REGION="westeurope"

################################################################################
# AKS Cluster Configuration
################################################################################

# Resource Group and Cluster
export TP_RESOURCE_GROUP="kul-atsbnl"
export TP_CLUSTER_NAME="dp1-aks-aauk-kul"
export TP_KUBERNETES_VERSION="1.32.6"
export KUBECONFIG="${HOME}/.kube/config"

# Network Configuration
export TP_VNET_NAME="${TP_CLUSTER_NAME}-vnet"
export TP_VNET_CIDR="10.4.0.0/16"
export TP_SERVICE_CIDR="10.0.0.0/16"
export TP_AKS_SUBNET_CIDR="10.4.0.0/20"
export TP_APISERVER_SUBNET_CIDR="10.4.19.0/28"

# Network Policy
export TP_NETWORK_POLICY=""  # Options: "" (disable), "calico", "azure"

################################################################################
# v1.16.0 DNS Configuration - Simplified Architecture
################################################################################

# Base DNS domain (simplified single-level subdomains)
export TP_TOP_LEVEL_DOMAIN="atsnl-emea.azure.dataplanes.pro"
export TP_SANDBOX="dp1"  # Environment identifier
export TP_BASE_DNS_DOMAIN="${TP_SANDBOX}.${TP_TOP_LEVEL_DOMAIN}"

# DNS: dp1.atsnl-emea.azure.dataplanes.pro
# This single domain is used for ALL services with simple subdomain prefixes:
# - admin.dp1.atsnl-emea.azure.dataplanes.pro (Control Plane Admin)
# - ai.dp1.atsnl-emea.azure.dataplanes.pro (Example subscription with hostPrefix: ai)
# - *.dp1.atsnl-emea.azure.dataplanes.pro (Wildcard for Data Plane apps)

################################################################################
# Control Plane Configuration (v1.16.0)
################################################################################

# Control Plane Instance Details
export CP_INSTANCE_ID="cp1"  # ⚠️ CRITICAL: NO HYPHENS! Used as PostgreSQL database prefix
export CP_NAMESPACE="${CP_INSTANCE_ID}-ns"
export CP_CHART_VERSION="1.16.0"  # TIBCO Control Plane chart version (tibco-cp-base)

# Domain Configuration for Control Plane (v1.16.0 format)
export CP_MY_DNS_DOMAIN="admin.${TP_BASE_DNS_DOMAIN}"

# Example subscription hostPrefix (this specific cluster has a subscription with hostPrefix: ai)
export CP_AI_DNS_DOMAIN="ai.${TP_BASE_DNS_DOMAIN}"  # This is just an example subscription, not a platform feature

# URLs
export TP_CP_ADMIN_URL="https://${CP_MY_DNS_DOMAIN}"

# Examples:
# CP_MY_DNS_DOMAIN = admin.dp1.atsnl-emea.azure.dataplanes.pro
# Subscription examples = ai.dp1.atsnl-emea.azure.dataplanes.pro, benelux.dp1.atsnl-emea.azure.dataplanes.pro

################################################################################
# Data Plane Configuration (v1.16.0)
################################################################################

# Data Plane Instance Details
export DP_INSTANCE_ID="dp1"
export DP_NAMESPACE="${DP_INSTANCE_ID}-ns"

# Domain Configuration for Data Plane
# v1.16.0: Uses wildcard DNS, no subdomain separation needed
export TP_DOMAIN="${TP_BASE_DNS_DOMAIN}"  # services.dp1.atsnl-emea.azure.dataplanes.pro pattern
export TP_MAIN_INGRESS_SANDBOX_SUBDOMAIN=""  # Empty = use base domain
export TP_DP_SANDBOX="${TP_SANDBOX}"  # = "dp1"

# Data Plane Connection to Control Plane
export TP_CP_MY_DOMAIN="${CP_MY_DNS_DOMAIN}"

# Examples of Data Plane app URLs and subscription URLs:
# - myapp.dp1.atsnl-emea.azure.dataplanes.pro (BWCE/Flogo apps)
# - api.dp1.atsnl-emea.azure.dataplanes.pro (APIs)
# - <hostPrefix>.dp1.atsnl-emea.azure.dataplanes.pro (Subscriptions with custom hostPrefix)

################################################################################
# Storage Configuration
################################################################################

# Azure Disk Storage (for EMS, PostgreSQL, Developer Hub)
export TP_DISK_ENABLED="true"
export TP_DISK_STORAGE_CLASS="azure-disk-sc"
export TP_DISK_STORAGE_SKU="Premium_LRS"

# Azure Files Storage (for BWCE, shared storage, Control Plane)
export TP_FILE_ENABLED="true"
export TP_FILE_STORAGE_CLASS="azure-files-sc"
export TP_FILE_STORAGE_SKU="Standard_LRS"

# Storage Account for Azure Files (create if needed)
export TP_STORAGE_ACCOUNT_NAME="kulatsbnlstorage"  # Must be globally unique, 3-24 chars, lowercase alphanumeric
export TP_STORAGE_ACCOUNT_RESOURCE_GROUP="${TP_RESOURCE_GROUP}"

# Storage Reclaim Policy
export STORAGE_RECLAIM_POLICY="Retain"

################################################################################
# Ingress Controller Configuration
################################################################################

# Primary Ingress Controller (Traefik)
export TP_INGRESS_CLASS="traefik"
export TP_MAIN_INGRESS_CONTROLLER="traefik"
export INGRESS_CONTROLLER="traefik"
export INGRESS_CLASS="traefik"
export INGRESS_NAMESPACE="ingress-system"

# LoadBalancer IP (from running environment)
export INGRESS_LOAD_BALANCER_IP="40.114.164.16"
export TP_INGRESS_SERVICE_TYPE="LoadBalancer"

# IP Whitelisting (comma-separated CIDR ranges)
export TP_AUTHORIZED_IP_RANGE="0.0.0.0/0"  # ⚠️ CHANGE THIS for production!
# Example: export TP_AUTHORIZED_IP_RANGE="1.2.3.4/32,10.0.0.0/8,80.60.0.0/16"

################################################################################
# DNS Configuration
################################################################################

# Azure DNS Zone
export TP_DNS_RESOURCE_GROUP="${TP_RESOURCE_GROUP}"
export TP_DNS_ZONE_NAME="${TP_TOP_LEVEL_DOMAIN}"  # atsnl-emea.azure.dataplanes.pro

# External DNS Configuration (for automatic DNS record creation)
export TP_EXTERNAL_DNS_ENABLED="true"
export TP_EXTERNAL_DNS_DOMAIN_FILTER="${TP_BASE_DNS_DOMAIN}"

# Wildcard DNS record managed by external-dns:
# *.dp1.atsnl-emea.azure.dataplanes.pro → 40.114.164.16

################################################################################
# PostgreSQL Database Configuration (Control Plane)
################################################################################

# Database Connection Details
# In-cluster PostgreSQL (deployed in tibco-ext namespace)
export TP_POSTGRES_HOST="postgresql.tibco-ext.svc.cluster.local"
export TP_POSTGRES_PORT="5432"
export TP_POSTGRES_DATABASE="postgres"
export TP_POSTGRES_USERNAME="postgres"
export TP_POSTGRES_PASSWORD="postgres"  # ⚠️ Change in production!

# Option 2: Azure Database for PostgreSQL Flexible Server (for production)
# export TP_POSTGRES_HOST="<server-name>.postgres.database.azure.com"
# export TP_POSTGRES_USERNAME="adminuser"
# export TP_POSTGRES_PASSWORD="<your-secure-password>"
# export TP_POSTGRES_SSL_MODE="require"

# SSL Configuration
export TP_POSTGRES_SSL_MODE="disable"  # Options: "disable", "require", "verify-ca", "verify-full"

################################################################################
# Container Registry Configuration
################################################################################

# TIBCO Container Registry (v1.16.0 - Updated credentials)
export TP_CONTAINER_REGISTRY="csgprdusw2reposaas.jfrog.io"
export TP_CONTAINER_REGISTRY_REPOSITORY="tibco-platform-docker-dev"
export TP_CONTAINER_REGISTRY_USERNAME="tibco-platform-devqa"
export TP_CONTAINER_REGISTRY_PASSWORD=""  # Set your actual password here
export TP_CONTAINER_REGISTRY_EMAIL="kul@tibco.com"

# Aliases for compatibility with other scripts
export CONTAINER_REGISTRY_SERVER="${TP_CONTAINER_REGISTRY}"
export CONTAINER_REGISTRY_USERNAME="${TP_CONTAINER_REGISTRY_USERNAME}"
export CONTAINER_REGISTRY_PASSWORD="${TP_CONTAINER_REGISTRY_PASSWORD}"

################################################################################
# Helm Chart Repository
################################################################################

export TP_TIBCO_HELM_CHART_REPO="https://tibcosoftware.github.io/tp-helm-charts"
export TP_HELM_REPO="${TP_TIBCO_HELM_CHART_REPO}"

################################################################################
# TIBCO Platform Version
################################################################################

export TP_VERSION="1.16.0"
export TP_CHART_VERSION="1.16.0"

################################################################################
# Observability Configuration (Existing Infrastructure)
################################################################################

# Elastic Stack for Logging (ECK Operator)
export TP_ES_RELEASE_NAME="dp-config-es"
export TP_ES_VERSION="8.17.3"
export ELASTIC_NAMESPACE="elastic-system"
export TP_ES_ENDPOINT="https://dp-config-es-es-http.elastic-system.svc.cluster.local:9200"
export TP_ES_USERNAME="elastic"
export TP_ES_PASSWORD="elasticpassword"

# Prometheus & Grafana (kube-prometheus-stack)
export TP_PROMETHEUS_ENABLED="true"
export TP_GRAFANA_ENABLED="true"
export PROMETHEUS_NAMESPACE="prometheus-system"
export PROMETHEUS_VERSION="48.3.4"

################################################################################
# Certificate Configuration
################################################################################

# Certificate email for Let's Encrypt
export CERT_EMAIL="kul@tibco.com"
export TP_CERT_EMAIL="${CERT_EMAIL}"

# Cert-Manager issuer
export CERT_ISSUER="letsencrypt-prod"
export TP_CERT_ISSUER="${CERT_ISSUER}"

# TLS Secret Name
export DEFAULT_INGRESS_TLS_SECRET="tp-custom-cert"

# Certificate paths (for self-signed certificates if needed)
export TP_TLS_CERT_MY="${HOME}/certs/cp-my-cert.pem"
export TP_TLS_KEY_MY="${HOME}/certs/cp-my-key.pem"

# Self-signed certificate paths (if not using Let's Encrypt)
export DEFAULT_INGRESS_CERT_FILE="./certs/${TP_BASE_DNS_DOMAIN}-cert.pem"
export DEFAULT_INGRESS_KEY_FILE="./certs/${TP_BASE_DNS_DOMAIN}-key.pem"

################################################################################
# Email/SMTP Configuration
################################################################################

# MailDev (for testing/workshops) - Deployed in tibco-ext namespace
export TP_MAILDEV_ENABLED="true"
export TP_SMTP_HOST="development-mailserver.tibco-ext.svc.cluster.local"
export TP_SMTP_PORT="1025"
export TP_SMTP_FROM="noreply@${TP_BASE_DNS_DOMAIN}"
export TP_MAILDEV_UI="https://mail.${TP_BASE_DNS_DOMAIN}"

# Option 2: Real SMTP Server (for production)
# export TP_MAILDEV_ENABLED="false"
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
# Azure-Specific Configuration
################################################################################

# Azure Managed Identity (if using)
export TP_USE_MANAGED_IDENTITY="false"
export TP_MANAGED_IDENTITY_CLIENT_ID=""

# Azure Key Vault (for secrets management)
export TP_KEY_VAULT_NAME=""
export TP_KEY_VAULT_RESOURCE_GROUP=""

################################################################################
# Debug Configuration
################################################################################

export DEBUG_MODE="false"

################################################################################
# Encryption Secret Configuration
################################################################################

export CP_ENCRYPTION_SECRET="CP_ENCRYPTION_SECRET"  # ⚠️ Change in production!

################################################################################
# Admin User Configuration
################################################################################

export CP_ADMIN_EMAIL="cpadmin@tibco.com"
export CP_ADMIN_FIRSTNAME="Platform"
export CP_ADMIN_LASTNAME="Admin"
export CP_ADMIN_CUSTOMER_ID="customerID"
export CP_ADMIN_PASSWORD="adminpassword"  # ⚠️ Change in production!

################################################################################
# End of Configuration
################################################################################

echo "✅ TIBCO Platform v1.16.0 environment variables configured successfully!"
echo ""
echo "Key Settings:"
echo "  Cluster: ${TP_CLUSTER_NAME}"
echo "  Version: ${TP_VERSION}"
echo "  Control Plane: ${CP_INSTANCE_ID} (namespace: ${CP_NAMESPACE})"
echo "  Admin URL: ${TP_CP_ADMIN_URL}"
echo "  Ingress: ${INGRESS_CONTROLLER} (${INGRESS_LOAD_BALANCER_IP})"
echo "  Storage: ${TP_FILE_STORAGE_CLASS}"
echo ""
echo "Note: Subscriptions can have custom hostPrefix (e.g., 'ai', 'benelux') creating URLs like:"
echo "  - <hostPrefix>.${TP_BASE_DNS_DOMAIN}"
echo ""
