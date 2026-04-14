#!/bin/bash
# Install TIBCO Platform Data Plane v1.15.0 with DNS Simplification

set -e

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-environment-v1.15.sh"

echo "=========================================="
echo "Installing TIBCO Platform Data Plane v1.15.0"
echo "=========================================="

# Validate prerequisites
validate_prerequisites || exit 1

# Check if token is set
if [[ -z "${TP_DP_TOKEN}" ]]; then
    echo ""
    echo "❌ ERROR: TP_DP_TOKEN is not set"
    echo ""
    echo "To set the Data Plane token:"
    echo "1. Login to Control Plane UI: https://admin.${TP_BASE_DNS_DOMAIN}"
    echo "2. Navigate to Settings → Data Planes"
    echo "3. Click 'Register Data Plane'"
    echo "4. Generate token and run:"
    echo "   export TP_DP_TOKEN=\"<your-token-here>\""
    echo "   echo 'export TP_DP_TOKEN=\"<your-token-here>\"' >> ./00-environment-v1.15.sh"
    echo ""
    exit 1
fi

# Create backup
create_backup

# Create namespace
echo ""
echo "📦 Creating namespace: ${TP_DP_NAMESPACE}..."
kubectl create namespace ${TP_DP_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Create service account
echo ""
echo "👤 Creating service account..."
kubectl create serviceaccount tibco-dp-sa -n ${TP_DP_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Create container registry secret
echo ""
echo "🔐 Creating container registry secret..."
kubectl create secret docker-registry tibco-container-registry-credentials \
  --docker-server="${CONTAINER_REGISTRY_SERVER}" \
  --docker-username="${CONTAINER_REGISTRY_USERNAME}" \
  --docker-password="${CONTAINER_REGISTRY_PASSWORD}" \
  --namespace ${TP_DP_NAMESPACE} \
  --dry-run=client -o yaml | kubectl apply -f -

# Create Data Plane token secret
echo ""
echo "🔐 Creating Data Plane token secret..."
kubectl create secret generic tibco-dp-token \
  --from-literal=token="${TP_DP_TOKEN}" \
  --namespace ${TP_DP_NAMESPACE} \
  --dry-run=client -o yaml | kubectl apply -f -

# Create Data Plane Helm values
echo ""
echo "📝 Creating Data Plane Helm values..."
cat > /tmp/dp-values-v1.15.yaml <<EOF
global:
  tibco:
    # Data Plane Identity
    dataPlaneInstanceId: "${TP_DP_INSTANCE_ID}"
    
    # v1.15.0: Simplified Control Plane URLs
    controlPlaneUrl: "https://admin.${TP_BASE_DNS_DOMAIN}"
    
    # Container Registry
    containerRegistry:
      url: "${CONTAINER_REGISTRY_SERVER}"
      username: "${CONTAINER_REGISTRY_USERNAME}"
      password: "${CONTAINER_REGISTRY_PASSWORD}"
    
    # Service Account
    serviceAccount: "tibco-dp-sa"
    
    # Logging
    logging:
      fluentbit:
        enabled: true
        elasticsearch:
          host: "dp-config-es-es-http.${ELASTIC_NAMESPACE}"
          port: 9200
          index: "dp-logs"

# Data Plane Configuration
dataPlane:
  # Control Plane Connection (v1.15.0 simplified)
  controlPlane:
    myDomain: "admin.${TP_BASE_DNS_DOMAIN}"
    tunnelDomain: "tunnel.${TP_BASE_DNS_DOMAIN}"
    tokenSecret: "tibco-dp-token"
    tokenSecretKey: "token"
  
  # v1.15.0: Simplified Data Plane domain
  # Applications will use: app-name.${TP_DP_BASE_DNS_DOMAIN}
  domain: "${TP_DP_BASE_DNS_DOMAIN}"
  ingressClassName: "${INGRESS_CLASS}"
  
  # Capabilities
  capabilities:
    # BWCE (BusinessWorks Container Edition)
    bwce:
      enabled: true
      storageClassName: "${RWX_STORAGE_CLASS}"
      resources:
        requests:
          cpu: "500m"
          memory: "1Gi"
        limits:
          cpu: "2000m"
          memory: "4Gi"
    
    # Flogo
    flogo:
      enabled: true
      storageClassName: "${RWX_STORAGE_CLASS}"
      resources:
        requests:
          cpu: "500m"
          memory: "1Gi"
        limits:
          cpu: "2000m"
          memory: "4Gi"
    
    # EMS (Enterprise Messaging Service)
    ems:
      enabled: true
      storageClassName: "${RWO_STORAGE_CLASS}"
      resources:
        requests:
          cpu: "500m"
          memory: "2Gi"
        limits:
          cpu: "2000m"
          memory: "4Gi"
    
    # BW5 (BusinessWorks 5) - Optional
    bw5:
      enabled: false

# Storage Configuration
storage:
  storageClassName: "${RWO_STORAGE_CLASS}"

# Ingress Configuration
ingress:
  enabled: true
  ingressClassName: "${INGRESS_CLASS}"
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    cert-manager.io/cluster-issuer: "${CERT_ISSUER}"

# Network Policy (optional)
networkPolicy:
  enabled: false

# Resource Limits for Data Plane Core
resources:
  requests:
    cpu: "1000m"
    memory: "2Gi"
  limits:
    cpu: "2000m"
    memory: "4Gi"

# High Availability
replicaCount: 2

# Pod Disruption Budget
podDisruptionBudget:
  enabled: true
  minAvailable: 1

# Monitoring Integration
monitoring:
  prometheus:
    enabled: true
    serviceMonitor:
      enabled: true
  elasticsearch:
    enabled: true
    host: "dp-config-es-es-http.${ELASTIC_NAMESPACE}"
    port: 9200
EOF

# Install Data Plane
echo ""
echo "🚀 Installing TIBCO Platform Data Plane v${TP_VERSION}..."
echo "This may take 10-15 minutes..."

helm install tibco-dp tibco-platform/tibco-platform-dp \
  --namespace ${TP_DP_NAMESPACE} \
  --values /tmp/dp-values-v1.15.yaml \
  --version ${TP_CHART_VERSION} \
  --timeout 20m \
  --wait

# Monitor deployment
echo ""
echo "📊 Monitoring deployment progress..."
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/component=dp-core-ops \
  -n ${TP_DP_NAMESPACE} \
  --timeout=600s || true

# Display status
echo ""
echo "=========================================="
echo "✅ Data Plane Installation Complete"
echo "=========================================="
echo ""
echo "📊 Data Plane Status:"
kubectl get pods -n ${TP_DP_NAMESPACE}

echo ""
echo "🌐 Data Plane Configuration (v1.15.0 Simplified DNS):"
echo "Data Plane ID: ${TP_DP_INSTANCE_ID}"
echo "Application Domain: *.${TP_DP_BASE_DNS_DOMAIN}"
echo "Control Plane URL: https://admin.${TP_BASE_DNS_DOMAIN}"

echo ""
echo "🔍 To check logs:"
echo "kubectl logs -n ${TP_DP_NAMESPACE} -l app.kubernetes.io/component=dp-core-ops -f"

echo ""
echo "📋 Verification Steps:"
echo "1. Check Data Plane status in Control Plane UI"
echo "2. Verify capabilities are available (BWCE, Flogo, EMS)"
echo "3. Deploy a test application"
echo ""
echo "To test DNS resolution:"
echo "dig +short test-app.${TP_DP_BASE_DNS_DOMAIN}"

# Cleanup
rm -f /tmp/dp-values-v1.15.yaml

echo ""
echo "🎉 Installation Complete!"
echo "Run ./05-post-install-verification.sh to verify the installation"
