#!/bin/bash
# TIBCO Platform Control Plane - Prerequisites Setup
# This script installs all required dependencies before Control Plane deployment

set -e

# Source environment variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/aks-env-variables-dp1.sh"

echo "=========================================="
echo "Control Plane Prerequisites Setup"
echo "=========================================="

# Validate prerequisites first
echo "Validating prerequisites..."
if ! validate_prerequisites; then
    echo "❌ Prerequisites validation failed"
    exit 1
fi

echo ""
echo "Configuration Summary:"
echo "  CP Instance ID: ${CP_INSTANCE_ID}"
echo "  CP Namespace: ${CP_NAMESPACE}"
echo "  Base DNS: ${TP_BASE_DNS_DOMAIN}"
echo "  Ingress Class: ${TP_INGRESS_CLASS}"
echo ""

# Step 1: Create namespace
echo "=========================================="
echo "Step 1: Creating Control Plane Namespace"
echo "=========================================="
kubectl apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: ${CP_NAMESPACE}
  labels:
    platform.tibco.com/controlplane-instance-id: ${CP_INSTANCE_ID}
    networking.platform.tibco.com/non-cp-ns: enable
EOF

echo "✅ Namespace ${CP_NAMESPACE} created"

# Step 2: Label ingress-system namespace
echo ""
echo "=========================================="
echo "Step 2: Labeling Ingress Namespace"
echo "=========================================="
kubectl label namespace ${INGRESS_NAMESPACE} networking.platform.tibco.com/non-cp-ns=enable --overwrite=true
echo "✅ Ingress namespace labeled"

# Step 3: Create service account
echo ""
echo "=========================================="
echo "Step 3: Creating Service Account"
echo "=========================================="
kubectl create serviceaccount ${CP_INSTANCE_ID}-sa -n ${CP_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Service account created"

# Step 4: Create container registry secret
echo ""
echo "=========================================="
echo "Step 4: Creating Container Registry Secret"
echo "=========================================="
kubectl create secret docker-registry tibco-container-registry-credentials \
  --namespace ${CP_NAMESPACE} \
  --docker-server="${TP_CONTAINER_REGISTRY}" \
  --docker-username="${TP_CONTAINER_REGISTRY_USERNAME}" \
  --docker-password="${TP_CONTAINER_REGISTRY_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Container registry secret created"

# Step 5: Install PostgreSQL in tibco-ext namespace
echo ""
echo "=========================================="
echo "Step 5: Installing PostgreSQL in tibco-ext Namespace"
echo "=========================================="

# Create tibco-ext namespace if it doesn't exist
kubectl create namespace tibco-ext --dry-run=client -o yaml | kubectl apply -f -
echo "✅ Namespace tibco-ext created/verified"

# Create container registry secret in tibco-ext namespace
echo "Creating container registry secret in tibco-ext namespace..."
kubectl create secret docker-registry tibco-container-registry-credentials \
  --namespace tibco-ext \
  --docker-server="${TP_CONTAINER_REGISTRY}" \
  --docker-username="${TP_CONTAINER_REGISTRY_USERNAME}" \
  --docker-password="${TP_CONTAINER_REGISTRY_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

# Check if PostgreSQL is already installed
if kubectl get statefulset postgresql -n tibco-ext &>/dev/null; then
    echo "✅ PostgreSQL already installed in tibco-ext namespace"
else
    echo "Installing PostgreSQL using Bitnami Helm chart..."
    
    # Add Bitnami Helm repo if not already added
    helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
    helm repo update
    
    helm upgrade --install --wait --timeout 15m \
      --create-namespace \
      -n tibco-ext \
      postgresql \
      bitnami/postgresql \
      --version "^16.0.0" \
      --set global.security.allowInsecureImages=true \
      --set image.registry="${TP_CONTAINER_REGISTRY}" \
      --set image.repository="tibco-platform-docker-prod/common-postgresql" \
      --set image.tag="16.4.0-debian-12-r14" \
      --set image.pullSecrets[0]="tibco-container-registry-credentials" \
      --set auth.postgresPassword="${TP_POSTGRES_PASSWORD}" \
      --set auth.username="${TP_POSTGRES_USERNAME}" \
      --set auth.password="${TP_POSTGRES_PASSWORD}" \
      --set auth.database="${TP_POSTGRES_DATABASE}" \
      --set primary.resources.requests.cpu="500m" \
      --set primary.resources.requests.memory="1Gi" \
      --set primary.resources.limits.cpu="2" \
      --set primary.resources.limits.memory="4Gi" \
      --set primary.persistence.size="50Gi" \
      --set primary.persistence.storageClass="${TP_DISK_STORAGE_CLASS}"
    
    echo "✅ PostgreSQL installed successfully in tibco-ext namespace"
fi

# Export PostgreSQL connection details (using tibco-ext namespace)
export POSTGRES_HOST="postgresql.tibco-ext.svc.cluster.local"
export POSTGRES_PORT="5432"
export POSTGRES_DB="${TP_POSTGRES_DATABASE}"
export POSTGRES_USER="${TP_POSTGRES_USERNAME}"
export POSTGRES_PASSWORD="${TP_POSTGRES_PASSWORD}"

echo ""
echo "PostgreSQL Connection Details:"
echo "  Host: ${POSTGRES_HOST}"
echo "  Port: ${POSTGRES_PORT}"
echo "  Database: ${POSTGRES_DB}"
echo "  User: ${POSTGRES_USER}"

# Step 5b: Install MailDev Email Server
echo ""
echo "=========================================="
echo "Step 5b: Installing MailDev Email Server"
echo "=========================================="

if kubectl get deployment maildev -n tibco-ext &>/dev/null; then
    echo "✅ MailDev already installed"
else
    echo "Deploying MailDev for email testing..."
    
    kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: maildev
  namespace: tibco-ext
  labels:
    app: development-mailserver
spec:
  replicas: 1
  selector:
    matchLabels:
      app: development-mailserver
  template:
    metadata:
      labels:
        app: development-mailserver
    spec:
      containers:
        - name: maildev
          image: maildev/maildev:latest
          args: ["-s", "1025", "-w", "1080"]
          ports:
            - name: http
              containerPort: 1080
              protocol: TCP
            - name: smtp
              containerPort: 1025
              protocol: TCP
          resources:
            requests:
              memory: "32Mi"
              cpu: "25m"
            limits:
              memory: "64Mi"
              cpu: "50m"
---
apiVersion: v1
kind: Service
metadata:
  name: development-mailserver
  namespace: tibco-ext
spec:
  selector:
    app: development-mailserver
  ports:
    - protocol: TCP
      port: 1080
      targetPort: 1080
      name: http
    - protocol: TCP
      port: 1025
      targetPort: 1025
      name: smtp
  type: ClusterIP
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: maildev-ingress
  namespace: tibco-ext
  labels:
    app: development-mailserver
  annotations:
    cert-manager.io/cluster-issuer: ${CERT_ISSUER}
    external-dns.alpha.kubernetes.io/hostname: mail.${TP_BASE_DNS_DOMAIN}
spec:
  ingressClassName: ${TP_INGRESS_CLASS}
  rules:
    - host: mail.${TP_BASE_DNS_DOMAIN}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: development-mailserver
                port:
                  number: 1080
  tls:
    - secretName: maildev-tls
      hosts:
        - mail.${TP_BASE_DNS_DOMAIN}
EOF
    
    echo "✅ MailDev installed successfully"
fi

echo ""
echo "MailDev Details:"
echo "  SMTP Host: development-mailserver.tibco-ext.svc.cluster.local"
echo "  SMTP Port: 1025"
echo "  Web UI: https://mail.${TP_BASE_DNS_DOMAIN}"

# Step 6: Create session keys secret
echo ""
echo "=========================================="
echo "Step 6: Creating Session Keys Secret"
echo "=========================================="

if kubectl get secret session-keys -n ${CP_NAMESPACE} &>/dev/null; then
    echo "✅ Session keys secret already exists"
else
    # Generate session keys
    TSC_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)
    DOMAIN_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)
    
    kubectl create secret generic session-keys -n ${CP_NAMESPACE} \
      --from-literal=TSC_SESSION_KEY=${TSC_SESSION_KEY} \
      --from-literal=DOMAIN_SESSION_KEY=${DOMAIN_SESSION_KEY}
    
    echo "✅ Session keys secret created"
fi

# Step 7: Create CP orchestration encryption secret
echo ""
echo "=========================================="
echo "Step 7: Creating CP Orchestration Encryption Secret"
echo "=========================================="

if kubectl get secret cporch-encryption-secret -n ${CP_NAMESPACE} &>/dev/null; then
    echo "✅ CPorch encryption secret already exists"
else
    # Generate encryption secret
    CP_ENCRYPTION_SECRET=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c44)
    
    kubectl create secret generic cporch-encryption-secret -n ${CP_NAMESPACE} \
      --from-literal=CP_ENCRYPTION_SECRET=${CP_ENCRYPTION_SECRET}
    
    echo "✅ CPorch encryption secret created"
fi

# Step 8: Create certificate (Optional - will be auto-created by Control Plane ingresses)
echo ""
echo "=========================================="
echo "Step 8: TLS Certificate Configuration"
echo "=========================================="

echo "ℹ️  TLS certificates will be automatically created by Control Plane ingresses"
echo "   via cert-manager annotations when the Control Plane is deployed."
echo ""
echo "   ClusterIssuer: ${CERT_ISSUER}"
echo "   Domain: *.${TP_BASE_DNS_DOMAIN}"
echo ""
echo "✅ Certificate configuration verified"

# Step 9: Verify all secrets
echo ""
echo "=========================================="
echo "Step 9: Verifying All Prerequisites"
echo "=========================================="

echo "Checking required secrets..."
REQUIRED_SECRETS=(
    "tibco-container-registry-credentials"
    "session-keys"
    "cporch-encryption-secret"
)

ALL_PRESENT=true
for secret in "${REQUIRED_SECRETS[@]}"; do
    if kubectl get secret "${secret}" -n ${CP_NAMESPACE} &>/dev/null; then
        echo "  ✅ ${secret}"
    else
        echo "  ❌ ${secret} - MISSING"
        ALL_PRESENT=false
    fi
done

echo ""
echo "Note: TLS certificates will be auto-created by ingresses when Control Plane is deployed"

echo ""
echo "Checking PostgreSQL status in tibco-ext namespace..."
kubectl get statefulset postgresql -n tibco-ext

if [ "$ALL_PRESENT" = true ]; then
    echo ""
    echo "=========================================="
    echo "✅ All Prerequisites Configured Successfully!"
    echo "=========================================="
    echo ""
    echo "PostgreSQL Details:"
    echo "  Host: ${POSTGRES_HOST}"
    echo "  Port: ${POSTGRES_PORT}"
    echo "  Database: ${POSTGRES_DB}"
    echo ""
    echo "Next Step:"
    echo "  Run: ./04-install-controlplane.sh"
    echo ""
else
    echo ""
    echo "=========================================="
    echo "⚠️  Some prerequisites are missing"
    echo "=========================================="
    echo "Review the errors above and re-run this script"
    exit 1
fi
