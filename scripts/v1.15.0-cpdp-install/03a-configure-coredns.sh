#!/bin/bash
################################################################################
# Script: 03a-configure-coredns.sh
# Description: Configure CoreDNS for internal DNS resolution of dp1 domain
# Version: 1.15.0
# Date: March 23, 2026
# 
# Purpose: Add custom CoreDNS configuration to rewrite dp1.atsnl-emea.azure.dataplanes.pro
#          to traefik.ingress-system.svc.cluster.local for internal resolution.
#          This fixes OAuth callback issues by preventing hairpin NAT.
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}CoreDNS Configuration for dp1 Domain${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Step 1: Verify kube-dns service
echo "Step 1: Verifying kube-dns service..."
DNS_IP=$(kubectl get svc -n kube-system kube-dns -o jsonpath='{.spec.clusterIP}')
if [ -z "$DNS_IP" ]; then
    echo -e "${RED}Error: Could not find kube-dns service${NC}"
    exit 1
fi
echo -e "${GREEN}✓ kube-dns ClusterIP: $DNS_IP${NC}"
echo ""

# Step 2: Verify traefik service
echo "Step 2: Verifying traefik service..."
TRAEFIK_IP=$(kubectl get svc -n ingress-system traefik -o jsonpath='{.spec.clusterIP}')
if [ -z "$TRAEFIK_IP" ]; then
    echo -e "${RED}Error: Could not find traefik service${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Traefik ClusterIP: $TRAEFIK_IP${NC}"
echo ""

# Step 3: Check if coredns-custom already exists
echo "Step 3: Checking for existing coredns-custom config..."
if kubectl get configmap coredns-custom -n kube-system >/dev/null 2>&1; then
    echo -e "${YELLOW}⚠ coredns-custom ConfigMap already exists${NC}"
    read -p "Do you want to replace it? (yes/no): " REPLACE
    if [ "$REPLACE" != "yes" ]; then
        echo "Skipping CoreDNS configuration"
        exit 0
    fi
    kubectl delete configmap coredns-custom -n kube-system
    echo -e "${GREEN}✓ Deleted existing coredns-custom${NC}"
fi
echo ""

# Step 4: Apply CoreDNS custom configuration
echo "Step 4: Applying CoreDNS custom configuration..."
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-custom
  namespace: kube-system
data:
  custom.server: |
    dp1.atsnl-emea.azure.dataplanes.pro:53 {
      errors
      forward . ${DNS_IP}
      rewrite name regex (.*)\.dp1\.atsnl-emea\.azure\.dataplanes\.pro traefik.ingress-system.svc.cluster.local
    }
  log.override: |
    # stub.server:
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ CoreDNS custom configuration applied${NC}"
else
    echo -e "${RED}✗ Failed to apply CoreDNS configuration${NC}"
    exit 1
fi
echo ""

# Step 5: Rollout restart CoreDNS
echo "Step 5: Restarting CoreDNS pods..."
kubectl rollout restart deployment coredns -n kube-system

echo "Waiting for CoreDNS to be ready..."
kubectl rollout status deployment coredns -n kube-system --timeout=60s

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ CoreDNS restarted successfully${NC}"
else
    echo -e "${RED}✗ CoreDNS restart timeout${NC}"
    exit 1
fi
echo ""

# Step 6: Verify DNS resolution
echo "Step 6: Testing DNS resolution..."
echo "Testing: admin.dp1.atsnl-emea.azure.dataplanes.pro"

kubectl run -n default dns-test --image=busybox:latest --rm -i --restart=Never --command -- \
  nslookup admin.dp1.atsnl-emea.azure.dataplanes.pro > /tmp/dns-test.log 2>&1

if grep -q "traefik.ingress-system.svc.cluster.local" /tmp/dns-test.log; then
    echo -e "${GREEN}✓ DNS rewrite is working! admin.dp1... resolves to traefik service${NC}"
else
    echo -e "${YELLOW}⚠ DNS rewrite may not be working yet. Check logs:${NC}"
    cat /tmp/dns-test.log
fi
rm -f /tmp/dns-test.log
echo ""

# Summary
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}CoreDNS Configuration Complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Configuration Summary:"
echo "  ✓ Custom DNS zone: dp1.atsnl-emea.azure.dataplanes.pro:53"
echo "  ✓ DNS forward: $DNS_IP"
echo "  ✓ Rewrite target: traefik.ingress-system.svc.cluster.local ($TRAEFIK_IP)"
echo ""
echo "What this fixes:"
echo "  • OAuth callbacks now work (no hairpin NAT)"
echo "  • Internal pods resolve dp1.atsnl... to Traefik ClusterIP"
echo "  • Eliminates external load balancer loopback"
echo ""
echo -e "${GREEN}You can now proceed with Control Plane login!${NC}"
