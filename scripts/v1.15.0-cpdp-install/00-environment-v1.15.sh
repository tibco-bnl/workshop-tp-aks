#!/bin/bash
# TIBCO Platform v1.15.0 CP+DP Installation - Environment Variables
# Cluster: dp1-aks-aauk-kul
# Date: March 18, 2026

# =============================================================================
# AZURE CONFIGURATION
# =============================================================================
export AZURE_SUBSCRIPTION="azrpsemeaneth-PresalesEMEANetherlands"
export AZURE_SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null || echo "")
export AZURE_RESOURCE_GROUP="kul-atsbnl"
export AZURE_LOCATION="westeurope"
export AKS_CLUSTER_NAME="dp1-aks-aauk-kul"

# =============================================================================
# v1.15.0 DNS SIMPLIFICATION - NEW ARCHITECTURE
# =============================================================================
# Base DNS domain for all services (simplified single-level subdomains)
export TP_BASE_DNS_DOMAIN="dp1.atsnl-emea.azure.dataplanes.pro"

# Control Plane domains (simplified format)
export TP_CP_DNS_DOMAIN="${TP_BASE_DNS_DOMAIN}"

# Data Plane domains (can be same as base or different)
export TP_DP_BASE_DNS_DOMAIN="${TP_BASE_DNS_DOMAIN}"

# =============================================================================
# INGRESS CONFIGURATION
# =============================================================================
export INGRESS_NAMESPACE="ingress-system"

# Ingress Controller: "nginx" or "traefik"
# Set to "traefik" after running 01b-migrate-nginx-to-traefik.sh
export INGRESS_CONTROLLER="traefik"  # Change to "traefik" after migration
export INGRESS_CLASS="${INGRESS_CONTROLLER}"

export INGRESS_LOAD_BALANCER_IP="128.251.247.140"

# IP Whitelisting (comma-separated CIDR ranges)
# Add your office/home IPs here for security
export TP_AUTHORIZED_IP_RANGE="0.0.0.0/0"  # CHANGE THIS for production!
# Example: export TP_AUTHORIZED_IP_RANGE="1.2.3.4/32,10.0.0.0/8"

# Ingress service type (LoadBalancer or Internal LoadBalancer)
export TP_INGRESS_SERVICE_TYPE="LoadBalancer"

# Default TLS secret name for custom certificates
export DEFAULT_INGRESS_TLS_SECRET="tp-custom-cert"

# =============================================================================
# STORAGE CONFIGURATION
# =============================================================================
export RWO_STORAGE_CLASS="azure-disk-sc"
export RWO_STORAGE_SKU="Premium_LRS"
export RWX_STORAGE_CLASS="azure-files-sc"
export RWX_STORAGE_SKU="Standard_LRS"
export STORAGE_RECLAIM_POLICY="Retain"

# =============================================================================
# OBSERVABILITY NAMESPACES
# =============================================================================
export ELASTIC_NAMESPACE="elastic-system"
export PROMETHEUS_NAMESPACE="prometheus-system"

# =============================================================================
# CONTROL PLANE CONFIGURATION
# =============================================================================
# Following TIBCO naming conventions: <instance-id>-ns
# Reference: https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#Installation/configuration-reference.htm
export TP_CP_INSTANCE_ID="cp1"
export TP_CP_NAMESPACE="${TP_CP_INSTANCE_ID}-ns"

# Control Plane Service URLs (v1.15.0 simplified format)
export TP_CP_ADMIN_URL="admin.${TP_CP_DNS_DOMAIN}"
export TP_CP_TUNNEL_URL="tunnel.${TP_CP_DNS_DOMAIN}"

# =============================================================================
# DATA PLANE CONFIGURATION
# =============================================================================
# Following TIBCO naming conventions: <instance-id>-ns
export TP_DP_INSTANCE_ID="dp1"
export TP_DP_NAMESPACE="${TP_DP_INSTANCE_ID}-ns"

# Data Plane Connection to Control Plane
export TP_CP_MY_DOMAIN="${TP_CP_ADMIN_URL}"
export TP_CP_TUNNEL_DOMAIN="${TP_CP_TUNNEL_URL}"

# =============================================================================
# CONTAINER REGISTRY
# =============================================================================
# Update with your container registry details
export CONTAINER_REGISTRY_SERVER="csgprdeuwrepoedge.jfrog.io"
export CONTAINER_REGISTRY_USERNAME="tibco-platform-sub-cn1q0bple0tljgoes3d0"
export CONTAINER_REGISTRY_PASSWORD=""  # Set your actual password here

# =============================================================================
# TIBCO PLATFORM VERSION
# =============================================================================
export TP_VERSION="1.15.0"
export TP_CHART_VERSION="1.15.0"

# Helm repository
export TP_HELM_REPO="https://tibcosoftware.github.io/tp-helm-charts"

# =============================================================================
# CERTIFICATES
# =============================================================================
export CERT_EMAIL="kul@tibco.com"
export CERT_ISSUER="letsencrypt-prod"

# Self-signed certificate paths (if not using Let's Encrypt)
export DEFAULT_INGRESS_CERT_FILE="./certs/${TP_BASE_DNS_DOMAIN}-cert.pem"
export DEFAULT_INGRESS_KEY_FILE="./certs/${TP_BASE_DNS_DOMAIN}-key.pem"

# =============================================================================
# BACKUP/LOGGING
# =============================================================================
# Set to true to enable verbose logging
export DEBUG_MODE="false"

# Backup directory for configuration files
export BACKUP_DIR="./backups/$(date +%Y%m%d-%H%M%S)"

# =============================================================================
# FUNCTIONS
# =============================================================================

# Function to display configuration
show_config() {
    echo "=========================================="
    echo "TIBCO Platform v1.15.0 Configuration"
    echo "=========================================="
    echo "Cluster: ${AKS_CLUSTER_NAME}"
    echo "Resource Group: ${AZURE_RESOURCE_GROUP}"
    echo "Location: ${AZURE_LOCATION}"
    echo ""
    echo "Base DNS Domain: ${TP_BASE_DNS_DOMAIN}"
    echo "CP Admin URL: https://${TP_CP_ADMIN_URL}"
    echo "CP Tunnel URL: https://${TP_CP_TUNNEL_URL}"
    echo ""
    echo "LoadBalancer IP: ${INGRESS_LOAD_BALANCER_IP}"
    echo "IP Whitelist: ${TP_AUTHORIZED_IP_RANGE}"
    echo ""
    echo "Storage Class (RWO): ${RWO_STORAGE_CLASS} (${RWO_STORAGE_SKU})"
    echo "Storage Class (RWX): ${RWX_STORAGE_CLASS} (${RWX_STORAGE_SKU})"
    echo ""
    echo "Elastic Namespace: ${ELASTIC_NAMESPACE}"
    echo "Prometheus Namespace: ${PROMETHEUS_NAMESPACE}"
    echo "=========================================="
}

# Function to validate prerequisites
validate_prerequisites() {
    echo "Validating prerequisites..."
    
    # Check Azure CLI
    if ! command -v az &> /dev/null; then
        echo "❌ Azure CLI not found. Please install it."
        return 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        echo "❌ kubectl not found. Please install it."
        return 1
    fi
    
    # Check helm
    if ! command -v helm &> /dev/null; then
        echo "❌ Helm not found. Please install it."
        return 1
    fi
    
    # Check Azure login
    if ! az account show &> /dev/null; then
        echo "❌ Not logged in to Azure. Run: az login"
        return 1
    fi
    
    # Check kubectl context
    local current_context=$(kubectl config current-context 2>/dev/null)
    if [[ "${current_context}" != "${AKS_CLUSTER_NAME}" ]]; then
        echo "⚠️  Warning: Current kubectl context is '${current_context}', expected '${AKS_CLUSTER_NAME}'"
        echo "Run: kubectl config use-context ${AKS_CLUSTER_NAME}"
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            return 1
        fi
    fi
    
    echo "✅ All prerequisites validated"
    return 0
}

# Function to create backup
create_backup() {
    mkdir -p "${BACKUP_DIR}"
    echo "Creating backup in ${BACKUP_DIR}..."
    
    # Backup existing Helm releases
    helm list -A -o yaml > "${BACKUP_DIR}/helm-releases.yaml" 2>/dev/null || true
    
    # Backup ingress configuration
    kubectl get svc -n ${INGRESS_NAMESPACE} -o yaml > "${BACKUP_DIR}/ingress-services.yaml" 2>/dev/null || true
    
    echo "✅ Backup created"
}

# Export functions
export -f show_config
export -f validate_prerequisites
export -f create_backup

# Display configuration if sourced interactively
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    show_config
fi

echo "✅ Environment variables loaded for TIBCO Platform v1.15.0"
echo "Run 'show_config' to display configuration"
echo "Run 'validate_prerequisites' to check prerequisites"
