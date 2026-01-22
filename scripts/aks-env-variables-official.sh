#!/bin/bash

################################################################################
# TIBCO Platform on AKS - Environment Variables Configuration
# Based on: https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/docs/workshop/aks
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
export TP_SUBSCRIPTION_ID=$(az account show --query id -o tsv 2>/dev/null || echo "<your-subscription-id>")
export TP_TENANT_ID=$(az account show --query tenantId -o tsv 2>/dev/null || echo "<your-tenant-id>")
export TP_AZURE_REGION="eastus"  # Change to your preferred Azure region

if [ -z "$TP_SUBSCRIPTION_ID" ] || [ "$TP_SUBSCRIPTION_ID" = "<your-subscription-id>" ]; then
  echo "⚠️  Warning: Please set your Azure subscription ID or run 'az login' first."
fi

################################################################################
# AKS Cluster Configuration
################################################################################

# Resource Group and Cluster
export TP_RESOURCE_GROUP="tibco-platform-rg"  # Azure resource group name
export TP_CLUSTER_NAME="tibco-aks-cluster"    # AKS cluster name
export TP_KUBERNETES_VERSION="1.32"            # Kubernetes version (1.32 or above - CNCF certified)
export KUBECONFIG=${KUBECONFIG:-~/.kube/config}  # Kubeconfig file path

# Network Configuration
export TP_VNET_NAME="${TP_CLUSTER_NAME}-vnet"
export TP_VNET_CIDR="10.4.0.0/16"              # CIDR of the VNet
export TP_SERVICE_CIDR="10.0.0.0/16"           # CIDR for service cluster IPs
export TP_AKS_SUBNET_CIDR="10.4.0.0/20"        # AKS subnet CIDR

# Network Policy
export TP_NETWORK_POLICY=""  # Options: "" (disable), "calico"

################################################################################
# TIBCO Helm Chart Repository (OFFICIAL)
################################################################################

export TP_TIBCO_HELM_CHART_REPO="https://tibcosoftware.github.io/tp-helm-charts"

################################################################################
# Domain Configuration
################################################################################

# DNS Configuration
export TP_DNS_RESOURCE_GROUP="${TP_RESOURCE_GROUP}"  # Resource group for DNS zone
export TP_TOP_LEVEL_DOMAIN="azure.example.com"       # Your top-level domain
export TP_SANDBOX="dp1"                               # Subdomain prefix for TP_DOMAIN
export TP_MAIN_INGRESS_SANDBOX_SUBDOMAIN="department"  # Sandbox subdomain to be used
export TP_DOMAIN="${TP_MAIN_INGRESS_SANDBOX_SUBDOMAIN}.${TP_SANDBOX}.${TP_TOP_LEVEL_DOMAIN}"

# Examples:
# TP_DOMAIN = department.dp1.azure.example.com

# Optional: Secondary domain for user apps (Kong ingress)
export TP_SECONDARY_INGRESS_SANDBOX_SUBDOMAIN="apps"
export TP_SECONDARY_DOMAIN="${TP_SECONDARY_INGRESS_SANDBOX_SUBDOMAIN}.${TP_SANDBOX}.${TP_TOP_LEVEL_DOMAIN}"

################################################################################
# Control Plane Configuration
################################################################################

# Control Plane Instance ID (alphanumeric, max 5 chars, NO HYPHENS)
export CP_INSTANCE_ID="cp1"

# Control Plane Domains
export CP_MY_DNS_DOMAIN="${TP_MAIN_INGRESS_SANDBOX_SUBDOMAIN}.${TP_SANDBOX}.${TP_TOP_LEVEL_DOMAIN}"
export CP_TUNNEL_DNS_DOMAIN="tunnel.${TP_SANDBOX}.${TP_TOP_LEVEL_DOMAIN}"

# Network Policy
export TP_ENABLE_NETWORK_POLICY="false"  # Set to "true" for production

################################################################################
# Data Plane Configuration
################################################################################

# Data Plane Namespace (commonly "ns" in TIBCO Platform)
export DP_NAMESPACE="ns"

################################################################################
# Ingress Controller Configuration
################################################################################

# Main Ingress Controller
export TP_INGRESS_CLASS="traefik"  # Options: "traefik" (recommended), "nginx"

# Secondary Ingress Controller (optional, for user apps)
export TP_SECONDARY_INGRESS_CLASS="kong"

################################################################################
# Storage Configuration
################################################################################

# Azure Disk Storage (for EMS data, PostgreSQL, Developer Hub)
export TP_DISK_ENABLED="true"
export TP_DISK_STORAGE_CLASS="azure-disk-sc"

# Azure Files Storage (for BWCE artifact manager, Flogo, shared storage)
export TP_FILE_ENABLED="true"
export TP_FILE_STORAGE_CLASS="azure-files-sc"

################################################################################
# TIBCO Container Registry (REQUIRED)
################################################################################

# JFrog Artifactory credentials
export TP_CONTAINER_REGISTRY_URL="csgprduswrepoedge.jfrog.io"
export TP_CONTAINER_REGISTRY_USER="<your-jfrog-username>"
export TP_CONTAINER_REGISTRY_PASSWORD="<your-jfrog-password>"
export TP_CONTAINER_REGISTRY_REPOSITORY="tibco-platform-docker-prod"

################################################################################
# PostgreSQL Database Configuration
################################################################################

# Option A: Azure PostgreSQL Flexible Server (RECOMMENDED for PRODUCTION)
export POSTGRES_SERVER_NAME="tibco-platform-db"
export POSTGRES_HOST="${POSTGRES_SERVER_NAME}.postgres.database.azure.com"
export POSTGRES_PORT="5432"
export POSTGRES_DB="postgres"
export POSTGRES_USER="pgadmin"
export POSTGRES_PASSWORD="<your-postgres-password>"  # Change this!

# Option B: In-cluster PostgreSQL (DEV/TEST ONLY - automatically set by dp-config-aks)
# export POSTGRES_HOST="postgres-${CP_INSTANCE_ID}-postgresql.${CP_INSTANCE_ID}-ns.svc.cluster.local"
# export POSTGRES_PORT="5432"
# export POSTGRES_DB="postgres"
# export POSTGRES_USER="postgres"
# export POSTGRES_PASSWORD="postgres"

################################################################################
# Observability Configuration
################################################################################

# Elastic Stack
export TP_ES_RELEASE_NAME="dp-config-es"  # Elastic stack release name

################################################################################
# Validation
################################################################################

echo ""
echo "=========================================="
echo "TIBCO Platform Configuration for AKS"
echo "=========================================="
echo "Azure Subscription: ${TP_SUBSCRIPTION_ID}"
echo "Resource Group: ${TP_RESOURCE_GROUP}"
echo "AKS Cluster: ${TP_CLUSTER_NAME}"
echo "Location: ${TP_AZURE_REGION}"
echo "Kubernetes Version: ${TP_KUBERNETES_VERSION}"
echo ""
echo "Helm Chart Repo: ${TP_TIBCO_HELM_CHART_REPO}"
echo ""
echo "Domain: ${TP_DOMAIN}"
echo "CP MY Domain: ${CP_MY_DNS_DOMAIN}"
echo "CP Tunnel Domain: ${CP_TUNNEL_DNS_DOMAIN}"
echo "Secondary Domain: ${TP_SECONDARY_DOMAIN}"
echo ""
echo "Ingress Class: ${TP_INGRESS_CLASS}"
echo "Secondary Ingress: ${TP_SECONDARY_INGRESS_CLASS}"
echo "Storage Class (Disk): ${TP_DISK_STORAGE_CLASS}"
echo "Storage Class (File): ${TP_FILE_STORAGE_CLASS}"
echo ""
echo "PostgreSQL Host: ${POSTGRES_HOST}"
echo "PostgreSQL Port: ${POSTGRES_PORT}"
echo "PostgreSQL Database: ${POSTGRES_DB}"
echo ""
echo "Control Plane Instance ID: ${CP_INSTANCE_ID}"
echo "Data Plane Namespace: ${DP_NAMESPACE}"
echo "Container Registry: ${TP_CONTAINER_REGISTRY_URL}"
echo "=========================================="

# Validation checks
echo ""
echo "Validation Checks:"
if [ "$TP_CONTAINER_REGISTRY_USER" = "<your-jfrog-username>" ]; then
  echo "❌ TIBCO Container Registry credentials NOT set"
else
  echo "✓ TIBCO Container Registry credentials set"
fi

if [ "$POSTGRES_PASSWORD" = "<your-postgres-password>" ]; then
  echo "❌ PostgreSQL password NOT set"
else
  echo "✓ PostgreSQL password set"
fi

if [ "$TP_SUBSCRIPTION_ID" = "<your-subscription-id>" ]; then
  echo "❌ Azure Subscription ID NOT set"
else
  echo "✓ Azure Subscription ID set"
fi

echo "=========================================="
echo ""
echo "To use these variables, source this script:"
echo "  source aks-env-variables.sh"
echo ""
