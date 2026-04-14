#!/bin/bash
# Migrate from NGINX Ingress to Traefik Ingress Controller

set -e

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/00-environment-v1.15.sh"

echo "=========================================="
echo "Migrating from NGINX to Traefik Ingress"
echo "=========================================="

# Create backup
create_backup

# Save current NGINX LoadBalancer IP
CURRENT_LB_IP=$(kubectl get svc dp-config-aks-nginx-ingress-nginx-controller -n ${INGRESS_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")

if [[ -z "${CURRENT_LB_IP}" ]]; then
    echo "⚠️  WARNING: Could not determine current LoadBalancer IP"
    echo "Using configured IP: ${INGRESS_LOAD_BALANCER_IP}"
else
    echo "📋 Current NGINX LoadBalancer IP: ${CURRENT_LB_IP}"
    if [[ "${CURRENT_LB_IP}" != "${INGRESS_LOAD_BALANCER_IP}" ]]; then
        echo "⚠️  WARNING: IP mismatch!"
        echo "   Current: ${CURRENT_LB_IP}"
        echo "   Expected: ${INGRESS_LOAD_BALANCER_IP}"
        read -p "Continue with current IP ${CURRENT_LB_IP}? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            export INGRESS_LOAD_BALANCER_IP="${CURRENT_LB_IP}"
        else
            echo "❌ Aborted"
            exit 1
        fi
    fi
fi

# Backup existing ingress resources
echo ""
echo "📦 Backing up existing ingress resources..."
kubectl get ingress -A -o yaml > "${BACKUP_DIR}/all-ingress-resources.yaml"
kubectl get svc -n ${INGRESS_NAMESPACE} -o yaml > "${BACKUP_DIR}/ingress-services.yaml"

# List applications that will be affected
echo ""
echo "📋 Applications using NGINX ingress:"
kubectl get ingress -A -o jsonpath='{range .items[?(@.spec.ingressClassName=="nginx")]}{.metadata.namespace}/{.metadata.name}{"\n"}{end}' | sort -u

echo ""
read -p "⚠️  These ingress resources will need to be updated. Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Migration cancelled"
    exit 1
fi

# Add Traefik Helm repository
echo ""
echo "📦 Adding Traefik Helm repository..."
helm repo add traefik https://traefik.github.io/charts
helm repo update

# Create Traefik namespace if needed
echo ""
echo "📦 Preparing Traefik namespace..."
TRAEFIK_NAMESPACE="${INGRESS_NAMESPACE}"
kubectl create namespace ${TRAEFIK_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -

# Create Traefik values with v1.15.0 enhancements
echo ""
echo "📝 Creating Traefik configuration..."
cat > /tmp/traefik-values.yaml <<EOF
# Traefik Configuration for TIBCO Platform v1.15.0

deployment:
  replicas: 2
  
service:
  type: ${TP_INGRESS_SERVICE_TYPE}
  # Preserve the existing LoadBalancer IP
  loadBalancerIP: "${INGRESS_LOAD_BALANCER_IP}"
  annotations:
    # Azure LoadBalancer health probe
    service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /ping
    # DNS annotation
    external-dns.alpha.kubernetes.io/hostname: "*.${TP_BASE_DNS_DOMAIN}"
EOF

# Add IP whitelisting if configured
if [[ "${TP_AUTHORIZED_IP_RANGE}" != "0.0.0.0/0" ]]; then
    cat >> /tmp/traefik-values.yaml <<EOF
    # IP whitelisting
    service.beta.kubernetes.io/load-balancer-source-ranges: "${TP_AUTHORIZED_IP_RANGE}"
EOF
fi

cat >> /tmp/traefik-values.yaml <<'EOF'

ports:
  web:
    port: 8000
    exposedPort: 80
  websecure:
    port: 8443
    exposedPort: 443
    http3:
      enabled: false
  # Health check port
  metrics:
    port: 9100
    expose:
      default: true

# Make Traefik the default ingress class
ingressClass:
  enabled: true
  isDefaultClass: true

# Enable CRD and Ingress providers
providers:
  kubernetesCRD:
    enabled: true
    allowCrossNamespace: true
    allowExternalNameServices: true
  kubernetesIngress:
    enabled: true
    allowExternalNameServices: true
    publishedService:
      enabled: true

# Logs (includes access logs)
logs:
  general:
    level: INFO
  access:
    enabled: true
    format: json

# Metrics for Prometheus
metrics:
  prometheus:
    enabled: true
    addEntryPointsLabels: true
    addRoutersLabels: true
    addServicesLabels: true
    entryPoint: metrics
    service:
      enabled: true
    serviceMonitor:
      enabled: true
      namespace: prometheus-system

# Resource limits
resources:
  requests:
    cpu: "500m"
    memory: "512Mi"
  limits:
    cpu: "2000m"
    memory: "2Gi"

# High Availability
affinity:
  podAntiAffinity:
    preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                  - traefik
          topologyKey: kubernetes.io/hostname

# Pod Disruption Budget
podDisruptionBudget:
  enabled: true
  minAvailable: 1

# Security Context
securityContext:
  capabilities:
    drop: [ALL]
    add: [NET_BIND_SERVICE]
  readOnlyRootFilesystem: true
  runAsGroup: 65532
  runAsNonRoot: true
  runAsUser: 65532

# Additional arguments
additionalArguments:
  - "--serverstransport.insecureskipverify=true"
  - "--providers.kubernetesingress.ingressendpoint.ip=${INGRESS_LOAD_BALANCER_IP}"
  - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
  - "--entrypoints.web.http.redirections.entrypoint.scheme=https"

# Persistence for certificates (optional)
persistence:
  enabled: false

# Traefik Dashboard (useful for monitoring and troubleshooting)
ingressRoute:
  dashboard:
    enabled: true
    # Dashboard will be available via port-forward or ingress
    # Access: kubectl port-forward -n ${TRAEFIK_NAMESPACE} svc/traefik 9000:9000
    # Then: http://localhost:9000/dashboard/
EOF

# Add dashboard ingress if you want external access
cat >> /tmp/traefik-values.yaml <<EOF

# Optional: Expose dashboard via ingress (configure after installation)
# Uncomment and apply manually if needed:
# ---
# apiVersion: traefik.containo.us/v1alpha1
# kind: IngressRoute
# metadata:
#   name: traefik-dashboard
#   namespace: ${TRAEFIK_NAMESPACE}
# spec:
#   entryPoints:
#     - websecure
#   routes:
#     - match: Host(\`traefik.${TP_BASE_DNS_DOMAIN}\`)
#       kind: Rule
#       services:
#         - name: api@internal
#           kind: TraefikService
#   tls: {}
EOF

# Install Traefik
echo ""
echo "🚀 Installing Traefik Ingress Controller..."
echo "This will preserve your LoadBalancer IP: ${INGRESS_LOAD_BALANCER_IP}"

helm install traefik traefik/traefik \
  --namespace ${TRAEFIK_NAMESPACE} \
  --values /tmp/traefik-values.yaml \
  --version 39.0.5 \
  --timeout 10m \
  --wait

# Wait for LoadBalancer IP assignment
echo ""
echo "⏳ Waiting for Traefik LoadBalancer IP..."
TRAEFIK_LB_IP=""
for i in {1..30}; do
    TRAEFIK_LB_IP=$(kubectl get svc traefik -n ${TRAEFIK_NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "")
    if [[ -n "${TRAEFIK_LB_IP}" ]]; then
        break
    fi
    echo "Waiting... (${i}/30)"
    sleep 10
done

if [[ -z "${TRAEFIK_LB_IP}" ]]; then
    echo "❌ ERROR: Traefik LoadBalancer IP not assigned"
    echo "Check: kubectl get svc traefik -n ${TRAEFIK_NAMESPACE}"
    exit 1
fi

echo ""
echo "✅ Traefik LoadBalancer IP: ${TRAEFIK_LB_IP}"

# Verify IP match
if [[ "${TRAEFIK_LB_IP}" != "${INGRESS_LOAD_BALANCER_IP}" ]]; then
    echo ""
    echo "⚠️  WARNING: IP address changed!"
    echo "   Expected: ${INGRESS_LOAD_BALANCER_IP}"
    echo "   Actual: ${TRAEFIK_LB_IP}"
    echo ""
    echo "You need to update DNS records to point to ${TRAEFIK_LB_IP}"
    echo "Or update the Traefik service to use the reserved IP"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Rolling back Traefik installation..."
        helm uninstall traefik -n ${TRAEFIK_NAMESPACE}
        exit 1
    fi
    export INGRESS_LOAD_BALANCER_IP="${TRAEFIK_LB_IP}"
fi

# Create a script to update existing ingress resources
echo ""
echo "📝 Creating ingress migration helper script..."
cat > /tmp/migrate-ingress-resources.sh <<'SCRIPT'
#!/bin/bash
# Helper script to migrate ingress resources from nginx to traefik

NAMESPACE=$1
if [[ -z "${NAMESPACE}" ]]; then
    echo "Usage: $0 <namespace>"
    echo "Example: $0 elastic-system"
    exit 1
fi

echo "Migrating ingress resources in namespace: ${NAMESPACE}"

# Get all nginx ingress resources
kubectl get ingress -n ${NAMESPACE} -o json | \
  jq '.items[] | select(.spec.ingressClassName=="nginx")' | \
  jq '.spec.ingressClassName = "traefik"' | \
  jq 'del(.metadata.uid, .metadata.resourceVersion, .metadata.creationTimestamp, .metadata.generation, .metadata.managedFields, .status)' | \
  kubectl apply -f -

echo "✅ Migration complete for namespace: ${NAMESPACE}"
echo "Verify with: kubectl get ingress -n ${NAMESPACE}"
SCRIPT

chmod +x /tmp/migrate-ingress-resources.sh

# Display migration status
echo ""
echo "=========================================="
echo "✅ Traefik Installation Complete"
echo "=========================================="
echo ""
echo "📊 Traefik Status:"
kubectl get pods -n ${TRAEFIK_NAMESPACE} -l app.kubernetes.io/name=traefik
echo ""
kubectl get svc traefik -n ${TRAEFIK_NAMESPACE}

echo ""
echo "=========================================="
echo "🔄 Next Steps: Migrate Existing Ingress Resources"
echo "=========================================="
echo ""
echo "Traefik is installed but NGINX is still running."
echo "You need to migrate existing ingress resources:"
echo ""
echo "1. Update ingresses in elastic-system:"
echo "   /tmp/migrate-ingress-resources.sh elastic-system"
echo ""
echo "2. Update ingresses in prometheus-system:"
echo "   /tmp/migrate-ingress-resources.sh prometheus-system"
echo ""
echo "3. Test Traefik ingress:"
echo "   curl -k -I https://kibana.${TP_BASE_DNS_DOMAIN}"
echo ""
echo "4. Once verified, you can remove NGINX:"
echo "   helm uninstall dp-config-aks-nginx -n ${INGRESS_NAMESPACE}"
echo "   helm uninstall dp-config-aks-ingress-certificate -n ${INGRESS_NAMESPACE}"
echo ""
echo "⚠️  DO NOT remove NGINX until you verify Traefik is working!"
echo ""
echo "📋 Ingress Classes:"
kubectl get ingressclass

echo ""
echo "🔍 Verify Traefik:"
echo "kubectl logs -n ${TRAEFIK_NAMESPACE} -l app.kubernetes.io/name=traefik -f"

# Cleanup
rm -f /tmp/traefik-values.yaml

echo ""
echo "Migration helper script saved: /tmp/migrate-ingress-resources.sh"
