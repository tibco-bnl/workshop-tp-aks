#!/bin/bash

################################################################################
# TIBCO Platform on AKS - Environment Variables Configuration
# 
# Cluster: dp1-aks-aauk-kul
# Environment: ATSBNL EMEA Presales
# TIBCO Platform Version: v1.15.0
# Ingress Controller: Traefik (migrated from NGINX)
#
# Usage:
#   1. Edit the container registry credentials below
#   2. Source this file: source aks-env-variables-dp1.sh
#   3. Verify variables: env | grep TP_
#
# Created: March 18, 2026
################################################################################

echo "Setting up TIBCO Platform v1.15.0 environment variables for dp1-aks-aauk-kul cluster..."

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
# v1.15.0 DNS Simplification - Single Domain Architecture
################################################################################

# Base DNS domain (simplified single-level subdomains)
export TP_TOP_LEVEL_DOMAIN="atsnl-emea.azure.dataplanes.pro"
export TP_SANDBOX="dp1"  # Environment identifier
export TP_BASE_DNS_DOMAIN="${TP_SANDBOX}.${TP_TOP_LEVEL_DOMAIN}"

# DNS: dp1.atsnl-emea.azure.dataplanes.pro
# This single domain is used for ALL services with simple subdomain prefixes:
# - admin.dp1.atsnl-emea.azure.dataplanes.pro (Control Plane Admin)
# - tunnel.dp1.atsnl-emea.azure.dataplanes.pro (Control Plane Tunnel)
# - *.dp1.atsnl-emea.azure.dataplanes.pro (Wildcard for Data Plane apps)

################################################################################
# Control Plane Configuration (v1.15.0)
################################################################################

# Control Plane Instance Details
export CP_INSTANCE_ID="cp1"  # ⚠️ CRITICAL: NO HYPHENS! Used as PostgreSQL database prefix
export CP_NAMESPACE="${CP_INSTANCE_ID}-ns"
export CP_CHART_VERSION="1.15.0"  # TIBCO Control Plane chart version (tibco-cp-base)

# Domain Configuration for Control Plane (v1.15.0 simplified format)
export CP_MY_DNS_DOMAIN="admin.${TP_BASE_DNS_DOMAIN}"
export CP_TUNNEL_DNS_DOMAIN="tunnel.${TP_BASE_DNS_DOMAIN}"

# URLs
export TP_CP_ADMIN_URL="https://${CP_MY_DNS_DOMAIN}"
export TP_CP_TUNNEL_URL="https://${CP_TUNNEL_DNS_DOMAIN}"

# Examples:
# CP_MY_DNS_DOMAIN = admin.dp1.atsnl-emea.azure.dataplanes.pro
# CP_TUNNEL_DNS_DOMAIN = tunnel.dp1.atsnl-emea.azure.dataplanes.pro

################################################################################
# Data Plane Configuration (v1.15.0)
################################################################################

# Data Plane Instance Details
export DP_INSTANCE_ID="dp1"
export DP_NAMESPACE="${DP_INSTANCE_ID}-ns"

# Domain Configuration for Data Plane
# v1.15.0: Uses wildcard DNS, no subdomain separation needed
export TP_DOMAIN="${TP_BASE_DNS_DOMAIN}"  # services.dp1.atsnl-emea.azure.dataplanes.pro pattern
export TP_MAIN_INGRESS_SANDBOX_SUBDOMAIN=""  # Empty = use base domain
export TP_DP_SANDBOX="${TP_SANDBOX}"  # = "dp1"

# Data Plane Connection to Control Plane
export TP_CP_MY_DOMAIN="${CP_MY_DNS_DOMAIN}"
export TP_CP_TUNNEL_DOMAIN="${CP_TUNNEL_DNS_DOMAIN}"

# Examples of Data Plane app URLs:
# - myapp.dp1.atsnl-emea.azure.dataplanes.pro (BWCE/Flogo apps)
# - api.dp1.atsnl-emea.azure.dataplanes.pro (APIs)

################################################################################
# Storage Configuration
################################################################################

# Azure Disk Storage (for EMS, PostgreSQL, Developer Hub)
export TP_DISK_ENABLED="true"
export TP_DISK_STORAGE_CLASS="azure-disk-sc"
export TP_DISK_STORAGE_SKU="Premium_LRS"

# Azure Files Storage (for BWCE, shared storage)
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

# Primary Ingress Controller (Traefik - migrated from NGINX on March 18, 2026)
export TP_INGRESS_CLASS="traefik"
export TP_MAIN_INGRESS_CONTROLLER="traefik"
export INGRESS_CONTROLLER="traefik"
export INGRESS_CLASS="traefik"
export INGRESS_NAMESPACE="ingress-system"

# LoadBalancer IP (assigned after NGINX to Traefik migration)
export INGRESS_LOAD_BALANCER_IP="20.54.225.126"
export TP_INGRESS_SERVICE_TYPE="LoadBalancer"

# IP Whitelisting (comma-separated CIDR ranges)
export TP_AUTHORIZED_IP_RANGE="0.0.0.0/0"  # ⚠️ CHANGE THIS for production!
# Example: export TP_AUTHORIZED_IP_RANGE="1.2.3.4/32,10.0.0.0/8,80.60.0.0/16"

# Optional: Secondary Ingress Controller for User Apps
# export TP_SECONDARY_INGRESS_CLASS="kong"  # Only for BWCE and Flogo apps

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
# *.dp1.atsnl-emea.azure.dataplanes.pro → 20.54.225.126

################################################################################
# PostgreSQL Database Configuration (Control Plane)
################################################################################

# Database Connection Details
# Option 1: In-cluster PostgreSQL (for dev/test) in tibco-ext namespace
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

# TIBCO Container Registry
export TP_CONTAINER_REGISTRY="csgprdeuwrepoedge.jfrog.io"
export TP_CONTAINER_REGISTRY_USERNAME="tibco-platform-sub-cn1q0bple0tljgoes3d0"
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

export TP_VERSION="1.15.0"
export TP_CHART_VERSION="1.15.0"

################################################################################
# Observability Configuration (Existing Infrastructure)
################################################################################

# Elastic Stack for Logging (ECK Operator)
export TP_ES_RELEASE_NAME="dp-config-es"
export TP_ES_VERSION="8.17.3"
export ELASTIC_NAMESPACE="elastic-system"

# Prometheus & Grafana (kube-prometheus-stack)
export TP_PROMETHEUS_ENABLED="true"
export TP_GRAFANA_ENABLED="true"
export PROMETHEUS_NAMESPACE="prometheus-system"
export PROMETHEUS_VERSION="48.3.4"  # Note: Needs upgrade to 69.3.3 for v1.15.0

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
export TP_TLS_CERT_TUNNEL="${HOME}/certs/cp-tunnel-cert.pem"
export TP_TLS_KEY_TUNNEL="${HOME}/certs/cp-tunnel-key.pem"

# Self-signed certificate paths (if not using Let's Encrypt)
export DEFAULT_INGRESS_CERT_FILE="./certs/${TP_BASE_DNS_DOMAIN}-cert.pem"
export DEFAULT_INGRESS_KEY_FILE="./certs/${TP_BASE_DNS_DOMAIN}-key.pem"

################################################################################
# Email/SMTP Configuration
################################################################################

# Option 1: MailDev (for testing/workshops) - Deployed in tibco-ext namespace
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
# Backup/Logging Configuration
################################################################################

# Debug mode
export DEBUG_MODE="false"

# Backup directory for configuration files
export BACKUP_DIR="./backups/$(date +%Y%m%d-%H%M%S)"

################################################################################
# Migration History
################################################################################

# NGINX to Traefik migration completed on March 18, 2026
# - Previous NGINX IP: 128.251.247.140 (released)
# - Current Traefik IP: 20.54.225.126 (active)
# - All 13 ingresses migrated successfully (elastic-system: 3, prometheus-system: 1, ai: 8, bpm: 1)
# - External-DNS managing wildcard DNS: *.dp1.atsnl-emea.azure.dataplanes.pro → 20.54.225.126

################################################################################
# Validation and Display Functions
################################################################################

# Function to display full configuration
show_config() {
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " TIBCO Platform v1.15.0 Configuration - dp1-aks-aauk-kul"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Azure Configuration:"
    echo "  Subscription:            ${TP_SUBSCRIPTION_NAME}"
    echo "  Subscription ID:         ${TP_SUBSCRIPTION_ID}"
    echo "  Resource Group:          ${TP_RESOURCE_GROUP}"
    echo "  Region:                  ${TP_AZURE_REGION}"
    echo ""
    echo "AKS Cluster:"
    echo "  Cluster Name:            ${TP_CLUSTER_NAME}"
    echo "  Kubernetes Version:      ${TP_KUBERNETES_VERSION}"
    echo ""
    echo "DNS Configuration (v1.15.0 Simplified):"
    echo "  Base DNS Domain:         ${TP_BASE_DNS_DOMAIN}"
    echo "  Top Level Domain:        ${TP_TOP_LEVEL_DOMAIN}"
    echo "  Environment/Sandbox:     ${TP_SANDBOX}"
    echo ""
    echo "Control Plane (v1.15.0):"
    echo "  Instance ID:             ${CP_INSTANCE_ID}"
    echo "  Namespace:               ${CP_NAMESPACE}"
    echo "  Chart Version:           ${CP_CHART_VERSION}"
    echo "  Admin URL:               ${TP_CP_ADMIN_URL}"
    echo "  Tunnel URL:              ${TP_CP_TUNNEL_URL}"
    echo "  MY Domain:               ${CP_MY_DNS_DOMAIN}"
    echo "  Tunnel Domain:           ${CP_TUNNEL_DNS_DOMAIN}"
    echo ""
    echo "Data Plane (v1.15.0):"
    echo "  Instance ID:             ${DP_INSTANCE_ID}"
    echo "  Namespace:               ${DP_NAMESPACE}"
    echo "  Base Domain:             ${TP_DOMAIN}"
    echo "  Sandbox:                 ${TP_DP_SANDBOX}"
    echo ""
    echo "Ingress Controller:"
    echo "  Controller:              ${TP_INGRESS_CLASS} (Traefik)"
    echo "  Namespace:               ${INGRESS_NAMESPACE}"
    echo "  LoadBalancer IP:         ${INGRESS_LOAD_BALANCER_IP}"
    echo "  Service Type:            ${TP_INGRESS_SERVICE_TYPE}"
    echo "  IP Whitelist:            ${TP_AUTHORIZED_IP_RANGE}"
    echo ""
    echo "Storage:"
    echo "  Disk Storage Class:      ${TP_DISK_STORAGE_CLASS} (${TP_DISK_STORAGE_SKU})"
    echo "  Files Storage Class:     ${TP_FILE_STORAGE_CLASS} (${TP_FILE_STORAGE_SKU})"
    echo "  Storage Account:         ${TP_STORAGE_ACCOUNT_NAME}"
    echo "  Reclaim Policy:          ${STORAGE_RECLAIM_POLICY}"
    echo ""
    echo "Observability:"
    echo "  Elasticsearch:           ${TP_ES_VERSION} (namespace: ${ELASTIC_NAMESPACE})"
    echo "  Prometheus:              ${PROMETHEUS_VERSION} (namespace: ${PROMETHEUS_NAMESPACE})"
    echo "  Note:                    Prometheus needs upgrade to 69.3.3 for v1.15.0"
    echo ""
    echo "PostgreSQL:"
    echo "  Host:                    ${TP_POSTGRES_HOST}"
    echo "  Port:                    ${TP_POSTGRES_PORT}"
    echo "  Database:                ${TP_POSTGRES_DATABASE}"
    echo "  Username:                ${TP_POSTGRES_USERNAME}"
    echo "  SSL Mode:                ${TP_POSTGRES_SSL_MODE}"
    echo ""
    echo "Container Registry:"
    echo "  Server:                  ${TP_CONTAINER_REGISTRY}"
    echo "  Username:                ${TP_CONTAINER_REGISTRY_USERNAME}"
    echo "  (Password set:           $([ -n \"${TP_CONTAINER_REGISTRY_PASSWORD}\" ] && echo \"Yes\" || echo \"No\"))"
    echo ""
    echo "Certificates:"
    echo "  Email:                   ${CERT_EMAIL}"
    echo "  Issuer:                  ${CERT_ISSUER}"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Function to validate prerequisites
validate_prerequisites() {
    echo "Validating prerequisites..."
    local errors=0
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        echo "❌ Azure CLI not found. Please install it."
        errors=$((errors+1))
    else
        echo "✅ Azure CLI found: $(az version --query '\"azure-cli\"' -o tsv)"
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        echo "❌ kubectl not found. Please install it."
        errors=$((errors+1))
    else
        echo "✅ kubectl found: $(kubectl version --client -o json 2>/dev/null | jq -r '.clientVersion.gitVersion' || echo 'version unknown')"
    fi
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        echo "❌ Helm not found. Please install it."
        errors=$((errors+1))
    else
        echo "✅ Helm found: $(helm version --short)"
    fi
    
    # Check Azure login
    if ! az account show &> /dev/null; then
        echo "❌ Not logged in to Azure. Run: az login"
        errors=$((errors+1))
    else
        echo "✅ Azure authenticated: $(az account show --query name -o tsv)"
    fi
    
    # Check kubectl context
    local current_context=$(kubectl config current-context 2>/dev/null || echo "")
    if [[ -z "${current_context}" ]]; then
        echo "❌ No kubectl context set"
        errors=$((errors+1))
    elif [[ "${current_context}" != "${TP_CLUSTER_NAME}" ]]; then
        echo "⚠️  Warning: Current kubectl context is '${current_context}', expected '${TP_CLUSTER_NAME}'"
        echo "   Run: kubectl config use-context ${TP_CLUSTER_NAME}"
    else
        echo "✅ kubectl context: ${current_context}"
    fi
    
    # Check container registry credentials
    if [[ "${TP_CONTAINER_REGISTRY_USERNAME}" == "<your-username>" ]]; then
        echo "⚠️  Warning: Container registry credentials not updated"
        errors=$((errors+1))
    else
        echo "✅ Container registry credentials set"
    fi
    
    echo ""
    if [[ $errors -eq 0 ]]; then
        echo "✅ All prerequisites validated successfully!"
        return 0
    else
        echo "❌ Found $errors error(s). Please fix before proceeding."
        return 1
    fi
}

# Function to create backup
create_backup() {
    mkdir -p "${BACKUP_DIR}"
    echo "Creating backup in ${BACKUP_DIR}..."
    
    # Backup existing Helm releases
    helm list -A -o yaml > "${BACKUP_DIR}/helm-releases.yaml" 2>/dev/null || true
    
    # Backup ingress configuration
    kubectl get ingress -A -o yaml > "${BACKUP_DIR}/all-ingress-resources.yaml" 2>/dev/null || true
    kubectl get svc -n ${INGRESS_NAMESPACE} -o yaml > "${BACKUP_DIR}/ingress-services.yaml" 2>/dev/null || true
    
    echo "✅ Backup created in ${BACKUP_DIR}"
}

# Export functions
export -f show_config
export -f validate_prerequisites
export -f create_backup

################################################################################
# Initialization
################################################################################

echo ""
echo "✅ Environment variables loaded for TIBCO Platform v1.15.0"
echo "   Cluster: ${TP_CLUSTER_NAME}"
echo "   Base DNS: ${TP_BASE_DNS_DOMAIN}"
echo "   Ingress: ${TP_INGRESS_CLASS} at ${INGRESS_LOAD_BALANCER_IP}"
echo ""
echo "Available commands:"
echo "  show_config                 - Display full configuration"
echo "  validate_prerequisites      - Check prerequisites"
echo "  create_backup              - Create backup of current state"
echo ""
echo "⚠️  Important Reminders:"
echo "  1. ✅ Container registry credentials configured"
echo "  2. Upgrade Prometheus from ${PROMETHEUS_VERSION} to 69.3.3 before CP/DP installation"
echo "  3. Review IP whitelist (TP_AUTHORIZED_IP_RANGE) for production security"
echo ""
echo "To view all TP_ variables: env | grep TP_"
echo ""
