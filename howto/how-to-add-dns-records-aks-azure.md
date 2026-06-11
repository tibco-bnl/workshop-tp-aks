---
layout: default
title: How to Add DNS Records for AKS Ingress in Azure
---

# How to Add DNS Records for AKS Ingress in Azure

This guide explains how to configure DNS records in Azure DNS for TIBCO Platform ingress routes on Azure Kubernetes Service (AKS).

**Target Audience**: Infrastructure administrators responsible for DNS management

**Last Updated**: June 11, 2026

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [DNS Strategy for TIBCO Platform](#dns-strategy-for-tibco-platform)
- [Method 1: Azure CLI (Automated)](#method-1-azure-cli-automated)
- [Method 2: Azure Portal (Manual)](#method-2-azure-portal-manual)
- [Method 3: External DNS (Recommended)](#method-3-external-dns-recommended)
- [Verification](#verification)
- [Troubleshooting](#troubleshooting)

---

## Overview

TIBCO Platform on AKS requires DNS records to route traffic from external domains to the Azure Load Balancer created by AKS ingress controllers. This guide covers three methods to manage these DNS records.

### Why DNS Records Are Needed

1. **Control Plane Access**: Users access Platform Console and subscription URLs through one base domain, for example `*.platform.azure.example.com`
2. **Hybrid Connectivity**: Data Planes connect through the same base domain; tunnel traffic is routed by path under `/infra/tunnel`
3. **Data Plane Services**: Applications accessible via `*.services.dp1.domain.com`

---

## Prerequisites

### Required Access

- [ ] Azure subscription with DNS Zone Contributor permissions
- [ ] Azure CLI installed (`az` command)
- [ ] kubectl access to AKS cluster
- [ ] Ingress controller deployed in AKS cluster

### Required Information

- [ ] Azure DNS Zone name (e.g., `azure.example.com`)
- [ ] Azure DNS Zone resource group
- [ ] AKS cluster name and resource group
- [ ] Ingress controller type (Traefik, NGINX, or Kong)

---

## DNS Strategy for TIBCO Platform

### Control Plane DNS Requirements

For current TIBCO Platform releases, use the simplified Control Plane DNS scheme unless you have an existing deployment that already separates access and tunnel domains.

| Domain Type | Pattern | Example | Purpose |
|------------|---------|---------|---------|
| **Simplified CP Domain** | `*.{base-domain}` | `*.platform.azure.example.com` | Platform Console, subscription URLs, APIs, and hybrid tunnel path |
| **Legacy MY Domain** | `*.{instanceId}-my.{domain}` | `*.cp1-my.platform.azure.example.com` | Older split-domain Control Plane UI and APIs |
| **Legacy TUNNEL Domain** | `*.{instanceId}-tunnel.{domain}` | `*.cp1-tunnel.platform.azure.example.com` | Older split-domain hybrid connectivity |

With simplified DNS, set both Helm values to the same base domain:

```yaml
global:
  external:
    dnsDomain: platform.azure.example.com
    dnsTunnelDomain: platform.azure.example.com
```

The resulting URLs use the same wildcard DNS record:

```text
admin.platform.azure.example.com              # Platform Console
<subscription>.platform.azure.example.com     # Subscription URL
<subscription>.platform.azure.example.com/infra/tunnel  # Hybrid tunnel path
```

### Data Plane DNS Requirements

| Domain Type | Pattern | Example | Purpose |
|------------|---------|---------|---------|
| **Services Domain** | `*.{subdomain}.{dp-name}.{domain}` | `*.services.dp1.azure.example.com` | Data Plane capabilities |
| **Apps Domain** | `*.{apps-subdomain}.{dp-name}.{domain}` | `*.apps.dp1.azure.example.com` | User applications (optional) |

### Wildcard vs Specific Records

#### Option 1: Simplified Wildcard DNS (Recommended)

**Pros:**
- Single record covers Platform Console, subscriptions, and tunnel path routing
- Easier to manage
- Supports dynamic subscription creation
- Matches current simplified Control Plane DNS configuration

**Cons:**
- May not be allowed by some corporate policies
- Less granular control

```
*.platform.azure.example.com → <Load-Balancer-IP>
```

#### Option 2: Legacy Split Wildcard DNS

Use this only for older deployments or when your organization intentionally separates access and tunnel ownership.

```
*.cp1-my.platform.azure.example.com → <Load-Balancer-IP>
*.cp1-tunnel.platform.azure.example.com → <Load-Balancer-IP>
```

#### Option 3: Specific Records

**Pros:**
- Explicit control over each hostname
- Complies with restrictive security policies

**Cons:**
- Requires knowing all hostnames in advance
- More maintenance overhead

```
admin.platform.azure.example.com → <Load-Balancer-IP>
subscription1.platform.azure.example.com → <Load-Balancer-IP>
```

---

## Method 1: Azure CLI (Automated)

### Step 1: Get Load Balancer Public IP

For **Traefik Ingress Controller**:

```bash
# Set variables
export CP_INSTANCE_ID="cp1"
export CP_NAMESPACE="${CP_INSTANCE_ID}-ns"

# Get Load Balancer IP
export LB_IP=$(kubectl get svc -n ingress-system traefik \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Load Balancer IP: $LB_IP"
```

For **NGINX Ingress Controller**:

```bash
export LB_IP=$(kubectl get svc -n ingress-system ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Load Balancer IP: $LB_IP"
```

### Step 2: Set Azure DNS Variables

```bash
# Azure DNS configuration
export TP_DNS_RESOURCE_GROUP="dns-resource-group"  # Resource group with DNS zone
export TP_DNS_ZONE_NAME="azure.example.com"        # Your DNS zone name
export TP_PLATFORM_SUBDOMAIN="platform"            # Subdomain for platform under the DNS zone

# Simplified Control Plane domain
export TP_BASE_DNS_DOMAIN="${TP_PLATFORM_SUBDOMAIN}.${TP_DNS_ZONE_NAME}"
export TP_CP_RECORD_SET="*.${TP_PLATFORM_SUBDOMAIN}"

# Use this same value for global.external.dnsDomain and global.external.dnsTunnelDomain
echo "Control Plane base domain: ${TP_BASE_DNS_DOMAIN}"
```

### Step 3: Create Wildcard DNS Records

```bash
# Create one wildcard A record for the simplified Control Plane domain
az network dns record-set a add-record \
  --resource-group "$TP_DNS_RESOURCE_GROUP" \
  --zone-name "$TP_DNS_ZONE_NAME" \
  --record-set-name "$TP_CP_RECORD_SET" \
  --ipv4-address "$LB_IP"

echo "Created DNS record: *.${TP_BASE_DNS_DOMAIN} -> $LB_IP"
```

For a legacy split-domain deployment, create separate records instead:

```bash
export CP_MY_DOMAIN="${CP_INSTANCE_ID}-my.${TP_PLATFORM_SUBDOMAIN}"
export CP_TUNNEL_DOMAIN="${CP_INSTANCE_ID}-tunnel.${TP_PLATFORM_SUBDOMAIN}"

az network dns record-set a add-record \
  --resource-group "$TP_DNS_RESOURCE_GROUP" \
  --zone-name "$TP_DNS_ZONE_NAME" \
  --record-set-name "*.${CP_MY_DOMAIN}" \
  --ipv4-address "$LB_IP"

az network dns record-set a add-record \
  --resource-group "$TP_DNS_RESOURCE_GROUP" \
  --zone-name "$TP_DNS_ZONE_NAME" \
  --record-set-name "*.${CP_TUNNEL_DOMAIN}" \
  --ipv4-address "$LB_IP"
```

### Step 4: Verify DNS Record Creation

```bash
# List all A records in the DNS zone
az network dns record-set a list \
  --resource-group "$TP_DNS_RESOURCE_GROUP" \
  --zone-name "$TP_DNS_ZONE_NAME" \
  --output table

# Query specific records
az network dns record-set a show \
  --resource-group "$TP_DNS_RESOURCE_GROUP" \
  --zone-name "$TP_DNS_ZONE_NAME" \
  --name "$TP_CP_RECORD_SET"
```

---

## Method 2: Azure Portal (Manual)

### Step 1: Navigate to DNS Zone

1. Sign in to [Azure Portal](https://portal.azure.com)
2. Search for **DNS zones** in the search bar
3. Select your DNS zone (e.g., `azure.example.com`)

### Step 2: Get Load Balancer IP

**Option A: From Azure Portal**

1. Navigate to **Kubernetes services**
2. Select your AKS cluster
3. Go to **Services and ingresses**
4. Find the ingress controller service (e.g., `traefik` or `ingress-nginx-controller`)
5. Copy the **External IP** address

**Option B: From kubectl**

```bash
kubectl get svc -n ingress-system
```

Copy the EXTERNAL-IP value.

### Step 3: Create DNS Record

1. In the DNS zone page, click **+ Record set**
2. Fill in the record details:

**For simplified Control Plane DNS:**
  - **Name**: `*.platform` (adjust based on your chosen base domain)
   - **Type**: A
   - **TTL**: 300 (or your preferred TTL)
   - **IP address**: Paste the Load Balancer IP

3. Click **OK** to create the record

For a legacy split-domain deployment, create two wildcard records instead:

4. Create the MY domain record:
  - **Name**: `*.cp1-my.platform`
  - **Type**: A
  - **TTL**: 300
  - **IP address**: Same Load Balancer IP

5. Create the TUNNEL domain record:
   - **Name**: `*.cp1-tunnel.platform`
   - **Type**: A
   - **TTL**: 300
   - **IP address**: Same Load Balancer IP

### Step 4: Verify Record Creation

1. In the DNS zone page, you should see the new A records listed
2. Click on each record to verify the IP address

---

## Method 3: External DNS (Recommended)

External DNS automatically manages Azure DNS records based on Kubernetes ingress resources.

### Benefits

- ✅ Automatic DNS record creation when ingress is created
- ✅ Automatic cleanup when ingress is deleted
- ✅ Reduces manual DNS management overhead
- ✅ Supports dynamic environments

### Prerequisites

- Azure Service Principal or Managed Identity with DNS Zone Contributor role
- External DNS helm chart or manifest

### Step 1: Create Service Principal (If Not Using Managed Identity)

```bash
# Create service principal for External DNS
export EXTERNAL_DNS_SP_NAME="external-dns-sp"
export AZURE_DNS_ZONE_ID=$(az network dns zone show \
  --resource-group "$TP_DNS_RESOURCE_GROUP" \
  --name "$TP_DNS_ZONE_NAME" \
  --query id -o tsv)

# Create service principal with DNS Zone Contributor role
az ad sp create-for-rbac \
  --name "$EXTERNAL_DNS_SP_NAME" \
  --role "DNS Zone Contributor" \
  --scopes "$AZURE_DNS_ZONE_ID" \
  --query '{client_id:appId, client_secret:password, tenant_id:tenant}' \
  -o json > external-dns-sp.json

# Save credentials
export EXTERNAL_DNS_CLIENT_ID=$(jq -r '.client_id' external-dns-sp.json)
export EXTERNAL_DNS_CLIENT_SECRET=$(jq -r '.client_secret' external-dns-sp.json)
export EXTERNAL_DNS_TENANT_ID=$(jq -r '.tenant_id' external-dns-sp.json)

echo "Service Principal created successfully!"
echo "⚠️  Store external-dns-sp.json securely and delete after creating Kubernetes secret!"
```

### Step 2: Create Kubernetes Secret

```bash
kubectl create namespace external-dns

kubectl create secret generic azure-config-file \
  --from-literal=azure.json="$(cat <<EOF
{
  "tenantId": "${EXTERNAL_DNS_TENANT_ID}",
  "subscriptionId": "${TP_SUBSCRIPTION_ID}",
  "resourceGroup": "${TP_DNS_RESOURCE_GROUP}",
  "aadClientId": "${EXTERNAL_DNS_CLIENT_ID}",
  "aadClientSecret": "${EXTERNAL_DNS_CLIENT_SECRET}"
}
EOF
)" \
  -n external-dns

# Securely delete the service principal file
rm -f external-dns-sp.json
```

### Step 3: Install External DNS

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

helm upgrade --install external-dns bitnami/external-dns \
  --namespace external-dns \
  --create-namespace \
  --set provider=azure \
  --set azure.resourceGroup="${TP_DNS_RESOURCE_GROUP}" \
  --set azure.tenantId="${EXTERNAL_DNS_TENANT_ID}" \
  --set azure.subscriptionId="${TP_SUBSCRIPTION_ID}" \
  --set azure.aadClientId="${EXTERNAL_DNS_CLIENT_ID}" \
  --set azure.aadClientSecret="${EXTERNAL_DNS_CLIENT_SECRET}" \
  --set domainFilters[0]="${TP_DNS_ZONE_NAME}" \
  --set policy=sync \
  --set txtOwnerId="${TP_CLUSTER_NAME}"
```

### Step 4: Verify External DNS

```bash
# Check External DNS pods
kubectl get pods -n external-dns

# Check External DNS logs
kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns --tail=50
```

### Step 5: Annotate Ingress for Automatic DNS

When creating ingress resources, add the `external-dns.alpha.kubernetes.io/hostname` annotation:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: tibco-cp-ingress
  namespace: cp1-ns
  annotations:
    external-dns.alpha.kubernetes.io/hostname: "*.platform.azure.example.com"
spec:
  ingressClassName: traefik
  tls:
  - hosts:
    - "*.platform.azure.example.com"
    secretName: tp-certificate-platform
  rules:
  - host: "*.platform.azure.example.com"
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: tibco-service
            port:
              number: 80
```

External DNS will automatically create the DNS records in Azure DNS!

---

## Verification

### Test DNS Resolution

```bash
# Test Platform Console domain
nslookup admin.platform.azure.example.com

# Test subscription domain
nslookup subscription1.platform.azure.example.com

# Test with dig (more detailed)
dig +short admin.platform.azure.example.com
```

Expected output: The Load Balancer IP address

### Test HTTP/HTTPS Access

```bash
# Test if ingress responds (before TIBCO Platform deployment)
curl -k https://admin.platform.azure.example.com

# Expected: 404 or default backend response (not connection error)
```

### Verify Azure DNS Records

```bash
# List all A records
az network dns record-set a list \
  --resource-group "$TP_DNS_RESOURCE_GROUP" \
  --zone-name "$TP_DNS_ZONE_NAME" \
  --query "[?name=='*.platform']" \
  --output table
```

---

## Troubleshooting

### DNS Record Not Resolving

**Problem**: `nslookup` returns "Non-existent domain"

**Solutions**:

1. **Check DNS propagation time**:
   ```bash
   # Azure DNS is usually fast (< 5 minutes), but check:
   az network dns record-set a show \
     --resource-group "$TP_DNS_RESOURCE_GROUP" \
     --zone-name "$TP_DNS_ZONE_NAME" \
     --name "*.platform"
   ```

2. **Verify DNS zone delegation**:
   ```bash
   # Get name servers for your DNS zone
   az network dns zone show \
     --resource-group "$TP_DNS_RESOURCE_GROUP" \
     --name "$TP_DNS_ZONE_NAME" \
     --query nameServers -o table
   
   # Verify your domain registrar has these NS records
   dig NS azure.example.com
   ```

3. **Use Azure DNS name servers directly**:
   ```bash
   # Query Azure DNS directly
  nslookup admin.platform.azure.example.com ns1-01.azure-dns.com
   ```

### Load Balancer IP Not Available

**Problem**: `kubectl get svc` shows `<pending>` for EXTERNAL-IP

**Solutions**:

1. **Check AKS service creation**:
   ```bash
   kubectl describe svc -n ingress-system traefik
   # Look for events related to Load Balancer creation
   ```

2. **Check Azure subscription quotas**:
   ```bash
   az vm list-usage --location eastus --query "[?name.value=='PublicIPAddresses']" -o table
   ```

3. **Verify NSG rules**:
   Ensure Network Security Group allows inbound traffic on ports 80 and 443.

### External DNS Not Creating Records

**Problem**: Ingress created but DNS records not appearing

**Solutions**:

1. **Check External DNS logs**:
   ```bash
   kubectl logs -n external-dns -l app.kubernetes.io/name=external-dns --tail=100
   ```

2. **Verify External DNS permissions**:
   ```bash
   # Test if service principal has correct permissions
   az role assignment list \
     --assignee "$EXTERNAL_DNS_CLIENT_ID" \
     --scope "$AZURE_DNS_ZONE_ID" \
     --output table
   ```

3. **Verify ingress annotation**:
   ```bash
   kubectl get ingress -n cp1-ns -o yaml | grep external-dns
   ```

### Certificate Mismatch Warnings

**Problem**: Browser shows certificate warnings

**Cause**: Certificate SAN doesn't match the domain

**Solutions**:

1. **Verify certificate SANs**:
   ```bash
   kubectl get secret tp-certificate-my -n cp1-ns -o json | \
     jq -r '.data."tls.crt"' | base64 -d | \
     openssl x509 -noout -text | grep -A1 "Subject Alternative Name"
   ```

2. **Regenerate certificates** with correct wildcard domains
3. **For production**, use certificates from trusted CA or cert-manager with Let's Encrypt

---

## Best Practices

### 1. Use Wildcard DNS

For flexibility and ease of management, use wildcard DNS records:
```
*.platform.azure.example.com
```

Use separate `*.cp1-my...` and `*.cp1-tunnel...` records only for legacy split-domain deployments.

### 2. Implement External DNS

Automate DNS management to reduce errors and manual overhead.

### 3. Use Short TTL During Testing

Set TTL to 60-300 seconds during initial setup for faster changes.

### 4. Increase TTL for Production

Once stable, increase TTL to 3600+ seconds for better caching.

### 5. Document DNS Records

Maintain documentation of all DNS records, their purposes, and associated services.

### 6. Monitor DNS Health

- Set up monitoring for DNS resolution
- Alert on DNS query failures
- Monitor External DNS logs for errors

### 7. Use Private DNS for Internal Services

For services that don't need public access, use Azure Private DNS zones.

---

## Summary

You've learned three methods to manage DNS records for TIBCO Platform on AKS:

1. **Azure CLI**: Quick and scriptable for initial setup
2. **Azure Portal**: Visual interface for manual management
3. **External DNS**: Automated, production-ready solution

**Recommended Approach**: Use **External DNS** for production environments to automate DNS management and reduce operational overhead.

---

## Next Steps

After configuring DNS:

1. **Verify DNS resolution** from external networks
2. **Deploy TIBCO Control Plane** and verify ingress access
3. **Configure SSL certificates** to match DNS domains
4. **Set up monitoring** for DNS health
5. **Document DNS configuration** for your environment

---

**Related Guides**:
- [Prerequisites Checklist](./prerequisites-checklist-for-customer)
- [Control Plane Setup Guide](./how-to-cp-and-dp-aks-setup-guide)
- [Certificate Generation Script](../scripts/generate-certificates.sh)
