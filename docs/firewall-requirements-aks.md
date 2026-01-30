# Firewall Requirements for TIBCO Platform Helm Charts Deployment on AKS

This document lists all external URLs and endpoints that need to be accessible for deploying TIBCO Platform on Azure Kubernetes Service using the tp-helm-charts repository.

**Repository**: https://github.com/TIBCOSoftware/tp-helm-charts  
**Generated**: January 23, 2026

---

## Official TIBCO Documentation References

**📖 Before configuring your firewall, review the official TIBCO Platform documentation:**

- **[TIBCO Platform Whitelisting Requirements](https://docs.tibco.com/pub/platform-cp/1.14.0/doc/html/UserGuide/whitelisting-requirements.htm)** - Official Control Plane firewall requirements
- **[Pushing Images to JFrog Registry](https://docs.tibco.com/pub/platform-cp/1.14.0/doc/html/UserGuide/pushing-images-to-registry.htm)** - JFrog container registry authentication and access
- **[TIBCO Platform Helm Charts Repository](https://github.com/TIBCOSoftware/tp-helm-charts)** - Official Helm charts and deployment guides

---

## Summary

The TIBCO Platform deployment requires access to:
- **4 Container Registries** for pulling images (TIBCO JFrog, Docker Hub, Quay.io, GitHub)
- **5 Helm Chart Repositories** for downloading charts
- **8+ External Services** for Kubernetes, monitoring, and documentation
- **3 Azure-specific endpoints** for storage and management
- **1 Go Module Proxy** for Flogo applications (if not using Flogo CLI)

**⚠️ CRITICAL REQUIREMENTS:**
1. **TIBCO JFrog Registry** (`csgprduswrepoedge.jfrog.io`) - All TIBCO Platform images
2. **TIBCO Helm Charts** (`tibcosoftware.github.io`) - Official Helm charts repository
3. **Go Module Proxy** (`proxy.golang.org`) - Required for Flogo applications unless built with Flogo CLI

---

## 1. Container Registries

These registries host the container images used by TIBCO Platform and its dependencies.

### TIBCO Container Registry (CRITICAL)

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `csgprduswrepoedge.jfrog.io` | 443 | HTTPS | **PRIMARY**: TIBCO Platform production images (CP, DP, capabilities) |

**⚠️ IMPORTANT:** This is the main TIBCO container registry. Access requires authentication with JFrog credentials.

**📖 Documentation**: [Pushing Images to JFrog Registry](https://docs.tibco.com/pub/platform-cp/1.14.0/doc/html/UserGuide/pushing-images-to-registry.htm)

---

### Public Container Registries

| URL | Port | Protocol | Purpose | Images Used |
|-----|------|----------|---------|-------------|
| `docker.io` | 443 | HTTPS | Docker Hub - PostgreSQL and Jaeger tracing | PostgreSQL (bitnami/postgresql:16.4.0), Jaeger (jaegertracing/*) |
| `quay.io` | 443 | HTTPS | Quay Container Registry - OAuth2 Proxy and Prometheus | OAuth2 Proxy (v7.1.0), Prometheus config reloader |
| `ghcr.io` | 443 | HTTPS | GitHub Container Registry - Message Gateway | TIBCO Message Gateway (tibco/msg-platform-cicd) |

---

### Microsoft Container Registry (for AKS)

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `mcr.microsoft.com` | 443 | HTTPS | Microsoft Container Registry - AKS system images |
| `*.azurecr.io` | 443 | HTTPS | Azure Container Registry (if using private registry) |

---

## 2. Helm Chart Repositories

These repositories host the Helm charts for TIBCO Platform and dependencies.

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `https://tibcosoftware.github.io/tp-helm-charts` | 443 | HTTPS | **PRIMARY**: TIBCO Platform official helm charts |
| `https://charts.jetstack.io` | 443 | HTTPS | cert-manager charts |
| `https://helm.elastic.co` | 443 | HTTPS | Elastic ECK operator charts |
| `https://kubernetes-sigs.github.io/external-dns` | 443 | HTTPS | External DNS charts |
| `https://prometheus-community.github.io/helm-charts` | 443 | HTTPS | Prometheus and Grafana stack charts |

---

## 3. Kubernetes and Cloud Provider APIs

### Azure-Specific Endpoints

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `disk.csi.azure.com` | 443 | HTTPS | Azure Disk CSI driver |
| `file.csi.azure.com` | 443 | HTTPS | Azure Files CSI driver |
| `learn.microsoft.com` | 443 | HTTPS | Azure documentation (optional) |
| `management.azure.com` | 443 | HTTPS | Azure Resource Manager API |
| `login.microsoftonline.com` | 443 | HTTPS | Azure AD authentication |
| `*.blob.core.windows.net` | 443 | HTTPS | Azure Blob Storage |
| `*.vault.azure.net` | 443 | HTTPS | Azure Key Vault (if used) |

---

## 4. Monitoring and Observability

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `prometheus.io` | 443 | HTTPS | Prometheus documentation |
| `opentelemetry.io` | 443 | HTTPS | OpenTelemetry documentation |
| `elastic.co` | 443 | HTTPS | Elastic documentation and downloads |

---

## 5. Source Code and Documentation

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `github.com` | 443 | HTTPS | GitHub - Source code, releases, documentation |
| `*.githubusercontent.com` | 443 | HTTPS | GitHub raw content |
| `ubuntu.com` | 443 | HTTPS | Ubuntu package repositories (for base images) |
| `kubernetes.io` | 443 | HTTPS | Kubernetes documentation and API references |
| `k8s.io` | 443 | HTTPS | Kubernetes documentation and tools |

---

## 6. Internal Cluster Communication (No Firewall Rules Needed)

These are internal cluster services that communicate within the Kubernetes cluster:

- `*.svc.cluster.local` - Internal Kubernetes service DNS
- `otel-userapp-traces.<namespace>.svc.cluster.local` - OTEL trace collector
- `otel-userapp-metrics.<namespace>.svc.cluster.local` - OTEL metrics collector
- `dp-config-es-es-http.elastic-system.svc.cluster.local` - Elasticsearch
- `kube-prometheus-stack-prometheus.prometheus-system.svc.cluster.local` - Prometheus

---

## 7. Complete Firewall Rules Summary

### Outbound Rules (From AKS to Internet)

#### Required (CRITICAL)
```
Protocol: HTTPS (443)
Destinations:
  - csgprduswrepoedge.jfrog.io              # TIBCO images
  - tibcosoftware.github.io                  # TIBCO helm charts
  - docker.io                                 # PostgreSQL, Jaeger
  - quay.io                                   # OAuth2 Proxy, Prometheus
  - ghcr.io                                   # Message Gateway
  - charts.jetstack.io                        # cert-manager
  - helm.elastic.co                           # Elastic ECK
  - kubernetes-sigs.github.io                 # External DNS
  - prometheus-community.github.io            # Prometheus stack
  - management.azure.com                      # Azure ARM
  - login.microsoftonline.com                 # Azure AD
  - disk.csi.azure.com                        # Azure Disk CSI
  - file.csi.azure.com                        # Azure Files CSI
  - proxy.golang.org                          # Go module proxy (Flogo)
  - sum.golang.org                            # Go checksum database (Flogo)
```

#### Recommended (HIGHLY RECOMMENDED)
```
Protocol: HTTPS (443)
Destinations:
  - mcr.microsoft.com                         # Microsoft Container Registry (AKS system)
  - *.azurecr.io                              # Azure Container Registry
  - github.com                                # GitHub
  - *.githubusercontent.com                   # GitHub raw content
  - *.blob.core.windows.net                   # Azure Blob Storage
  - kubernetes.io                             # Kubernetes docs
  - k8s.io                                    # Kubernetes docs
```

#### Optional (For Documentation and Troubleshooting)
```
Protocol: HTTPS (443)
Destinations:
  - learn.microsoft.com                       # Azure docs
  - prometheus.io                             # Prometheus docs
  - opentelemetry.io                          # OpenTelemetry docs
  - elastic.co                                # Elastic docs
  - ubuntu.com                                # Ubuntu packages
```

---

## 8. Network Security Group (NSG) Rules for Azure

If using Azure Network Security Groups, create the following outbound rules:

### Priority 100: TIBCO Container Registry
```
Source: VirtualNetwork
Destination: Service Tag - Internet
Destination Port: 443
Protocol: TCP
Action: Allow
Description: Allow TIBCO JFrog container registry
```

### Priority 110: Helm Chart Repositories
```
Source: VirtualNetwork
Destination: Service Tag - Internet
Destination Port: 443
Protocol: TCP
Action: Allow
Description: Allow Helm chart repositories (tibcosoftware, charts.jetstack, etc.)
```

### Priority 120: Azure Management
```
Source: VirtualNetwork
Destination: Service Tag - AzureCloud
Destination Port: 443
Protocol: TCP
Action: Allow
Description: Allow Azure Resource Manager and Azure AD
```

### Priority 130: Container Registries
```
Source: VirtualNetwork
Destination: Service Tag - Internet
Destination Port: 443
Protocol: TCP
Action: Allow
Description: Allow Docker Hub, GitHub Container Registry, MCR
```

---

## 9. Azure Firewall Application Rules

If using Azure Firewall, create the following application rule collections:

### Rule Collection: TIBCO-Platform-Required
```yaml
Priority: 100
Action: Allow
Rules:
  - Name: TIBCO-Container-Registry
    Source Addresses: <AKS_SUBNET_CIDR>
    Protocols: https:443
    Target FQDNs:
      - csgprduswrepoedge.jfrog.io
  
  - Name: TIBCO-Helm-Charts
    Source Addresses: <AKS_SUBNET_CIDR>
    Protocols: https:443
    Target FQDNs:
      - tibcosoftware.github.io
  
  - Name: Third-Party-Helm-Charts
    Source Addresses: <AKS_SUBNET_CIDR>
    Protocols: https:443
    Target FQDNs:
      - charts.jetstack.io
      - helm.elastic.co
      - kubernetes-sigs.github.io
      - prometheus-community.github.io
  
  - Name: Container-Registries
    Source Addresses: <AKS_SUBNET_CIDR>
    Protocols: https:443
    Target FQDNs:
      - docker.io
      - quay.io
      - ghcr.io
      - mcr.microsoft.com
      - *.azurecr.io
  
  - Name: Azure-Services
    Source Addresses: <AKS_SUBNET_CIDR>
    Protocols: https:443
    Target FQDNs:
      - management.azure.com
      - login.microsoftonline.com
      - disk.csi.azure.com
      - file.csi.azure.com
      - *.blob.core.windows.net
  
  - Name: Go-Module-Proxy-Flogo
    Source Addresses: <AKS_SUBNET_CIDR>
    Protocols: https:443
    Target FQDNs:
      - proxy.golang.org
      - sum.golang.org
```

---

## 10. TIBCO Flogo Go Module Proxy (CRITICAL for Flogo Apps)

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `https://proxy.golang.org` | 443 | HTTPS | **CRITICAL**: Go module proxy for Flogo applications |
| `https://sum.golang.org` | 443 | HTTPS | Go checksum database for module verification |

**⚠️ IMPORTANT:** 
- **Required for TIBCO Flogo applications** that are NOT built using the Flogo CLI
- The Kubernetes cluster must have outbound access to `https://proxy.golang.org`
- This is the official Go module proxy that Flogo runtime uses to download dependencies
- Without access to this endpoint, Flogo applications will fail to start if they have external Go module dependencies
- If using the Flogo CLI to build applications, this endpoint may not be required as dependencies are bundled

**Workaround**: If you cannot allow access to `proxy.golang.org`, build all Flogo applications using the Flogo CLI which bundles dependencies.

---

## 11. Proxy Configuration for Enterprise Environments

If your enterprise has a secure HTTP/HTTPS proxy already configured, you can configure TIBCO Platform to use it instead of opening all firewall rules.

### 11.1 Prerequisites

- HTTP/HTTPS proxy server already deployed and operational
- Proxy allows HTTPS traffic to required endpoints (see sections above)
- Proxy authentication credentials (if required)

### 11.2 Configure AKS Nodes for Proxy

Configure proxy settings on AKS nodes using cloud-init or custom script extensions:

```bash
# /etc/environment or /etc/profile.d/proxy.sh
export HTTP_PROXY="http://proxy.company.com:8080"
export HTTPS_PROXY="http://proxy.company.com:8080"
export NO_PROXY="localhost,127.0.0.1,169.254.169.254,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,.svc,.svc.cluster.local,<AKS_SERVICE_CIDR>,<AKS_POD_CIDR>,.azure.com"

# Lowercase versions (some applications require these)
export http_proxy="$HTTP_PROXY"
export https_proxy="$HTTPS_PROXY"
export no_proxy="$NO_PROXY"
```

**NO_PROXY must include**:
- `localhost`, `127.0.0.1` - Local host
- `169.254.169.254` - Azure metadata service
- `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` - Private IP ranges
- `.svc`, `.svc.cluster.local` - Kubernetes service discovery
- `<AKS_SERVICE_CIDR>` - Your AKS service CIDR (e.g., `10.0.0.0/16`)
- `<AKS_POD_CIDR>` - Your AKS pod CIDR (e.g., `10.244.0.0/16`)
- `.azure.com` - Azure service endpoints (or use Azure Private Link instead)

### 11.3 Configure TIBCO Platform Control Plane Proxy Settings

After installing the TIBCO Platform Control Plane, configure proxy settings through the UI or via Helm values.

**Reference Documentation**: [TIBCO Platform - Updating Proxy Configuration](https://docs.tibco.com/pub/platform-cp/1.14.0/doc/html/Default.htm#UserGuide/updating-proxy-configuration.htm)

#### Option 1: Configure via Control Plane UI

1. Login to TIBCO Platform Control Plane UI
2. Navigate to **Settings** → **Infrastructure** → **Proxy Configuration**
3. Configure the following settings:

```yaml
HTTP Proxy: http://proxy.company.com:8080
HTTPS Proxy: http://proxy.company.com:8080
No Proxy: localhost,127.0.0.1,.svc,.svc.cluster.local,169.254.169.254,10.0.0.0/8
Proxy Username: <username> (if authentication required)
Proxy Password: <password> (if authentication required)
```

4. Click **Save** and **Apply Configuration**

#### Option 2: Configure via Helm Values

Include proxy configuration in your `tibco-cp-base` values file:

```yaml
# tibco-cp-base-values.yaml
global:
  tibco:
    # Proxy configuration
    proxy:
      enabled: true
      httpProxy: "http://proxy.company.com:8080"
      httpsProxy: "http://proxy.company.com:8080"
      noProxy: "localhost,127.0.0.1,.svc,.svc.cluster.local,169.254.169.254,10.0.0.0/8"
      # Optional: Proxy authentication
      username: "<username>"
      password: "<password>"
```

Then upgrade the Control Plane:

```bash
helm upgrade --install -n ${CP_INSTANCE_ID}-ns tibco-cp-base tibco-platform-public/tibco-cp-base \
  --version "${CP_TIBCO_CP_BASE_VERSION}" \
  -f tibco-cp-base-values.yaml
```

### 11.4 Configure TIBCO Platform Data Plane Proxy Settings

Configure proxy settings for the Data Plane similarly:

```yaml
# dp-configure-namespace values
global:
  tibco:
    proxy:
      enabled: true
      httpProxy: "http://proxy.company.com:8080"
      httpsProxy: "http://proxy.company.com:8080"
      noProxy: "localhost,127.0.0.1,.svc,.svc.cluster.local,169.254.169.254,10.0.0.0/8"
```

### 11.5 Configure Flogo Applications for Go Module Proxy

For TIBCO Flogo applications that are NOT built using the Flogo CLI, configure the Go module proxy:

#### Option 1: Use Corporate Proxy for proxy.golang.org

Ensure your corporate proxy allows access to:
- `https://proxy.golang.org`
- `https://sum.golang.org`

No additional configuration needed if AKS nodes are already configured with proxy settings.

#### Option 2: Use Private Go Module Proxy (Athens or Artifactory)

If your enterprise has a private Go module proxy:

```yaml
# Flogo application environment variables
env:
  - name: GOPROXY
    value: "https://go-proxy.company.com,https://proxy.golang.org,direct"
  - name: GOSUMDB
    value: "sum.golang.org"
  - name: GOPRIVATE
    value: "github.com/company/*"  # Private modules
```

#### Option 3: Build with Flogo CLI (Recommended)

**Best Practice**: Build all Flogo applications using the Flogo CLI to bundle dependencies:

```bash
# Build Flogo application with bundled dependencies
flogo build --embed-config true --optimize true

# This eliminates the need for proxy.golang.org access at runtime
```

### 11.6 Verify Proxy Configuration

After configuring proxy settings, verify connectivity:

```bash
# Test from a pod
kubectl run test-proxy --image=curlimages/curl --rm -it --restart=Never -- \
  sh -c 'echo "HTTP_PROXY=$HTTP_PROXY"; curl -I https://proxy.golang.org'

# Check Control Plane proxy settings
kubectl get configmap -n ${CP_INSTANCE_ID}-ns -o yaml | grep -i proxy

# Check Data Plane proxy settings
kubectl get configmap -n ${DP_NAMESPACE} -o yaml | grep -i proxy
```

### 11.7 Proxy Configuration Best Practices

1. **Use HTTPS proxy** if available for encrypted traffic
2. **Configure NO_PROXY carefully** to avoid routing internal traffic through proxy
3. **Test thoroughly** after proxy configuration changes
4. **Monitor proxy logs** for blocked connections or authentication issues
5. **Document proxy exceptions** required for TIBCO Platform
6. **Use Azure Private Link** for Azure services to bypass proxy
7. **Rotate proxy credentials** regularly if authentication is required

### 11.8 Troubleshooting Proxy Issues

**Issue**: Pods cannot pull images through proxy
```bash
# Check containerd proxy configuration on nodes
ssh to AKS node
systemctl show containerd --property Environment

# Restart container runtime if needed
systemctl restart containerd
```

**Issue**: Flogo applications fail to download Go modules
```bash
# Check GOPROXY setting in pod
kubectl exec -it <flogo-pod> -- env | grep GOPROXY

# Test Go module proxy access
kubectl exec -it <flogo-pod> -- curl -v https://proxy.golang.org
```

**Issue**: Control Plane services cannot reach external APIs
```bash
# Check proxy configuration in Control Plane namespace
kubectl get configmap -n ${CP_INSTANCE_ID}-ns -o yaml | grep -A 5 proxy

# Check pod environment variables
kubectl exec -it <cp-pod> -n ${CP_INSTANCE_ID}-ns -- env | grep -i proxy
```

---

## 12. DNS Requirements

Ensure the following DNS resolutions work from within the AKS cluster:

### External DNS
- `csgprduswrepoedge.jfrog.io`
- `tibcosoftware.github.io`
- `docker.io`
- `ghcr.io`
- `mcr.microsoft.com`
- `management.azure.com`
- `login.microsoftonline.com`

### Azure-Specific DNS
- `*.blob.core.windows.net`
- `*.vault.azure.net`
- `<region>.management.azure.com`

### Internal DNS (CoreDNS)
- `*.svc.cluster.local` (internal service discovery)

---

## 13. Testing Connectivity

After configuring firewall rules, test connectivity from within the AKS cluster:

### Test Container Registry Access
```bash
# Test TIBCO JFrog registry
kubectl run test-jfrog --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://csgprduswrepoedge.jfrog.io

# Test Docker Hub
kubectl run test-docker --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://docker.io

# Test GitHub Container Registry
kubectl run test-ghcr --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://ghcr.io
```

### Test Helm Repository Access
```bash
# Test TIBCO Helm charts
kubectl run test-helm --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://tibcosoftware.github.io/tp-helm-charts/index.yaml

# Test cert-manager charts
kubectl run test-certmgr --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://charts.jetstack.io/index.yaml
```

### Test Azure Connectivity
```bash
# Test Azure management
kubectl run test-azure --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://management.azure.com

# Test Azure AD
kubectl run test-azuread --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://login.microsoftonline.com
```

### Test Go Module Proxy (Flogo)
```bash
# Test proxy.golang.org (critical for Flogo)
kubectl run test-goproxy --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://proxy.golang.org

# Test sum.golang.org
kubectl run test-gosum --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://sum.golang.org
```

---

## 14. Troubleshooting

### Common Issues

**Issue**: Cannot pull images from `csgprduswrepoedge.jfrog.io`
**Solution**: 
1. Verify firewall allows HTTPS (443) to `csgprduswrepoedge.jfrog.io`
2. Check JFrog credentials are correctly configured
3. Test with: `docker login csgprduswrepoedge.jfrog.io`

**Issue**: Helm install fails with "failed to download chart"
**Solution**:
1. Verify access to `tibcosoftware.github.io`
2. Check proxy settings if applicable
3. Test with: `helm repo add tibco https://tibcosoftware.github.io/tp-helm-charts && helm repo update`

**Issue**: Azure CSI drivers not working
**Solution**:
1. Ensure access to `disk.csi.azure.com` and `file.csi.azure.com`
2. Verify Azure managed identity or service principal has correct permissions
3. Check node logs: `kubectl logs -n kube-system -l app=csi-azuredisk-node`

**Issue**: cert-manager certificates not issuing
**Solution**:
1. Verify access to `charts.jetstack.io` for initial installation
2. For Let's Encrypt, ensure outbound port 80/443 to Let's Encrypt ACME servers
3. Check cert-manager logs: `kubectl logs -n cert-manager -l app=cert-manager`

**Issue**: Flogo applications fail to start with Go module errors
**Solution**:
1. **Most Common**: Verify access to `proxy.golang.org` and `sum.golang.org`
2. Check pod logs: `kubectl logs <flogo-pod> | grep -i "proxy.golang.org"`
3. Verify GOPROXY environment variable: `kubectl exec <flogo-pod> -- env | grep GOPROXY`
4. **Workaround**: Build Flogo applications using Flogo CLI to bundle dependencies

---

## 15. Security Considerations

### Least Privilege Access
- Only allow outbound traffic to required destinations
- Use Azure Private Link for Azure services where possible
- Implement Network Policies within the cluster

### Credential Management
- Store JFrog credentials in Azure Key Vault
- Use managed identities for Azure service authentication
- Rotate credentials regularly

### Monitoring
- Enable Azure Firewall logs
- Monitor NSG flow logs
- Set up alerts for blocked connections

---

## 16. Simplified Firewall Request Template

For enterprise environments with strict firewall policies, use this template to submit a firewall request that covers most TIBCO Platform deployment requirements.

### Generic Internet Access on Port 443 (Recommended Approach)

**Request Type**: Outbound Internet Access  
**Protocol**: HTTPS  
**Port**: 443  
**Direction**: Outbound (from AKS cluster to Internet)

#### Option 1: Broad Access (Simplest)

```
Source: <AKS_SUBNET_CIDR> (e.g., 10.1.0.0/16)
Destination: Any (0.0.0.0/0)
Port: 443
Protocol: TCP
Action: Allow
Justification: Required for TIBCO Platform deployment - container image pulls, 
helm chart downloads, and cloud provider API access
```

**Pros**: Covers all required and optional endpoints  
**Cons**: Less secure, may not meet compliance requirements  
**Use Case**: Development/test environments, PoC deployments

#### Option 2: Service Tag Based (Azure Recommended)

```yaml
Source: <AKS_SUBNET_CIDR>
Destination Service Tags:
  - Internet (for TIBCO JFrog, Helm repos, Docker Hub, GitHub)
  - AzureCloud (for Azure management and authentication)
Port: 443
Protocol: TCP
Action: Allow
```

**Pros**: Better security, uses Azure service tags  
**Cons**: Still broad Internet access  
**Use Case**: Production environments with moderate security requirements

#### Option 3: FQDN-Based (Most Secure)

For maximum security, request access to specific FQDNs only:

```yaml
Rule Name: TIBCO-Platform-HTTPS-Access
Source: <AKS_SUBNET_CIDR>
Destination Type: FQDN
Port: 443
Protocol: HTTPS

Required FQDNs (CRITICAL - Must be approved):
  - csgprduswrepoedge.jfrog.io          # TIBCO container images
  - tibcosoftware.github.io              # TIBCO helm charts
  - docker.io                            # Docker Hub
  - ghcr.io                              # GitHub Container Registry
  - mcr.microsoft.com                    # Microsoft Container Registry
  - charts.jetstack.io                   # cert-manager
  - helm.elastic.co                      # Elastic ECK
  - kubernetes-sigs.github.io            # External DNS
  - prometheus-community.github.io       # Prometheus
  - management.azure.com                 # Azure Resource Manager
  - login.microsoftonline.com           # Azure AD
  - disk.csi.azure.com                  # Azure Disk CSI
  - file.csi.azure.com                  # Azure Files CSI
  - *.blob.core.windows.net             # Azure Blob Storage
  - proxy.golang.org                     # Go module proxy (Flogo)
  - sum.golang.org                       # Go checksum database (Flogo)

Optional FQDNs (Recommended):
  - github.com                           # Source code and releases
  - *.githubusercontent.com              # GitHub raw content
  - k8s.io                               # Kubernetes
  - kubernetes.io                        # Kubernetes
  - *.azurecr.io                         # Azure Container Registry
  - *.vault.azure.net                    # Azure Key Vault
  - learn.microsoft.com                  # Documentation
  - prometheus.io                        # Documentation
  - elastic.co                           # Documentation
```

**Pros**: Most secure, explicit FQDN allow-list  
**Cons**: Requires Azure Firewall (Premium recommended for FQDN filtering)  
**Use Case**: Production environments with strict security requirements

### Sample Firewall Request Form

Use this template when submitting to your network/security team:

```
FIREWALL REQUEST - TIBCO PLATFORM ON AKS

Request ID: [Auto-generated or manual]
Requested By: [Your Name]
Team: [Your Team]
Date: [Current Date]
Environment: [Production/Staging/Development]

1. BUSINESS JUSTIFICATION
   Deployment of TIBCO Platform Control Plane and Data Plane on Azure 
   Kubernetes Service (AKS) for [business purpose]. Requires outbound 
   Internet access to pull container images, download Helm charts, and 
   access Azure cloud services.

2. SOURCE
   - Type: Azure Subnet
   - CIDR: [e.g., 10.1.0.0/16]
   - Description: AKS cluster subnet
   - Resource Group: [e.g., rg-tibco-platform-prod]
   - Subscription: [Azure Subscription ID]

3. DESTINATION
   - Option A (Recommended): Internet (0.0.0.0/0) with Azure Service Tags
   - Option B (Secure): FQDN-based (see attached FQDN list)
   - Option C (Most Secure): Specific IP ranges (requires IP resolution)

4. PORTS AND PROTOCOLS
   - Port: 443
   - Protocol: TCP/HTTPS
   - Direction: Outbound only

5. REQUIRED ENDPOINTS (Critical - Cannot deploy without these)
   - csgprduswrepoedge.jfrog.io (TIBCO container registry)
   - tibcosoftware.github.io (TIBCO Helm charts)
   - docker.io (Docker Hub)
   - management.azure.com (Azure Resource Manager)
   - login.microsoftonline.com (Azure AD)

6. OPTIONAL ENDPOINTS (Highly recommended for full functionality)
   - charts.jetstack.io, helm.elastic.co, prometheus-community.github.io
   - mcr.microsoft.com, ghcr.io
   - *.blob.core.windows.net, disk.csi.azure.com, file.csi.azure.com

7. DURATION
   - Permanent (required for ongoing platform operations)

8. SECURITY CONSIDERATIONS
   - All traffic is HTTPS (encrypted)
   - Authentication required for TIBCO JFrog registry
   - Managed identities used for Azure service authentication
   - Network policies implemented within cluster

9. COMPLIANCE & AUDIT
   - Azure Firewall logs enabled: [Yes/No]
   - NSG flow logs enabled: [Yes/No]
   - Log Analytics workspace: [Workspace ID]

10. ROLLBACK PLAN
    If firewall rules cause issues, disable specific FQDN rules while 
    keeping Azure management endpoints active.

11. TESTING PLAN
    Post-approval, validate connectivity using kubectl test pods:
    - Test TIBCO JFrog: curl -I https://csgprduswrepoedge.jfrog.io
    - Test Helm repos: curl -I https://tibcosoftware.github.io
    - Test Azure: curl -I https://management.azure.com

12. ATTACHMENTS
    - Full FQDN list (see Section 7 of this document)
    - NSG rules (see Section 8)
    - Azure Firewall rules (see Section 9)
```

### Quick Tips for Firewall Request Approval

1. **Start broad, refine later**: Request Internet access on 443 initially, then lock down after successful deployment
2. **Emphasize encryption**: All traffic is HTTPS (encrypted), reducing security concerns
3. **Highlight Azure native**: Most endpoints are Microsoft-owned (Azure, GitHub, Docker Hub)
4. **Provide business value**: Tie request to business objectives and project timelines
5. **Offer monitoring**: Commit to enabling firewall logs and regular reviews
6. **Include expiration**: Even for permanent rules, offer annual review
7. **Test quickly**: Schedule connectivity testing immediately after approval

### Alternative: Air-Gapped Deployment

If firewall approval is denied or delayed, consider air-gapped deployment:

1. **Mirror container images**: Copy all images to internal container registry
2. **Host Helm charts locally**: Clone tp-helm-charts repo to internal Git/Artifactory
3. **Disable external dependencies**: Use local PostgreSQL, disable telemetry
4. **Manual updates**: Download updates on separate machine, transfer via secure channel

**Note**: Air-gapped deployment requires significantly more effort and maintenance.

---

## 17. References

- [TIBCO Platform Helm Charts](https://github.com/TIBCOSoftware/tp-helm-charts)
- [TIBCO Platform Proxy Configuration](https://docs.tibco.com/pub/platform-cp/1.14.0/doc/html/Default.htm#UserGuide/updating-proxy-configuration.htm)
- [Azure Kubernetes Service Network Concepts](https://learn.microsoft.com/en-us/azure/aks/concepts-network)
- [Azure Firewall Application Rules](https://learn.microsoft.com/en-us/azure/firewall/rule-processing)
- [AKS Outbound Network Rules](https://learn.microsoft.com/en-us/azure/aks/limit-egress-traffic)
- [Go Module Proxy](https://proxy.golang.org)

---

**Document Version**: 1.1  
**Last Updated**: January 29, 2026  
**Generated From**: /Users/kul/git/tib/tp-helm-charts
