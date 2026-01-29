# Firewall Requirements for TIBCO Platform Helm Charts Deployment on EKS

This document lists all external URLs and endpoints that need to be accessible for deploying TIBCO Platform on Amazon Elastic Kubernetes Service (EKS) using the tp-helm-charts repository.

**Repository**: https://github.com/TIBCOSoftware/tp-helm-charts  
**Generated**: January 29, 2026  
**Cloud Provider**: Amazon Web Services (AWS)

---

## Summary

The TIBCO Platform deployment on EKS requires access to:
- **7 Container Registries** for pulling images
- **5 Helm Chart Repositories** for downloading charts
- **8+ External Services** for Kubernetes, monitoring, and documentation
- **5 AWS-specific endpoints** for EKS, ECR, and other AWS services
- **1 Go Module Proxy** for Flogo applications (if not using Flogo CLI)

---

## 1. Container Registries

These registries host the container images used by TIBCO Platform and its dependencies.

### TIBCO Container Registry (CRITICAL)

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `csgprduswrepoedge.jfrog.io` | 443 | HTTPS | **PRIMARY**: TIBCO Platform production images (CP, DP, capabilities) |

**⚠️ IMPORTANT:** This is the main TIBCO container registry. Access requires authentication with JFrog credentials.

---

### Public Container Registries

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `docker.io` | 443 | HTTPS | Docker Hub - Third-party and open-source images |
| `registry-1.docker.io` | 443 | HTTPS | Docker Hub registry endpoint |
| `ghcr.io` | 443 | HTTPS | GitHub Container Registry - Community images |
| `quay.io` | 443 | HTTPS | Red Hat Quay - Container images |
| `gcr.io` | 443 | HTTPS | Google Container Registry - Third-party images |
| `k8s.gcr.io` | 443 | HTTPS | Kubernetes legacy registry (being migrated) |
| `registry.k8s.io` | 443 | HTTPS | Kubernetes official registry (new) |

---

### AWS Container Registry (for EKS)

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `*.ecr.<region>.amazonaws.com` | 443 | HTTPS | Amazon Elastic Container Registry - EKS system images |
| `*.dkr.ecr.<region>.amazonaws.com` | 443 | HTTPS | ECR Docker registry endpoint |
| `public.ecr.aws` | 443 | HTTPS | Amazon ECR Public Gallery |

**Note**: Replace `<region>` with your AWS region (e.g., `us-east-1`, `eu-west-1`, `ap-southeast-1`)

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
| `https://aws.github.io/eks-charts` | 443 | HTTPS | AWS EKS add-on charts |

---

## 3. Kubernetes and Cloud Provider APIs

### Kubernetes API Endpoints

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `kubernetes.io` | 443 | HTTPS | Kubernetes documentation and API references |
| `k8s.io` | 443 | HTTPS | Kubernetes package repositories |
| `api.kubernetes.io` | 443 | HTTPS | Kubernetes API server |
| `*.eks.amazonaws.com` | 443 | HTTPS | EKS cluster API endpoints |

### AWS-Specific Endpoints

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `*.amazonaws.com` | 443 | HTTPS | Generic AWS services |
| `ec2.amazonaws.com` | 443 | HTTPS | EC2 API for node management |
| `elasticloadbalancing.amazonaws.com` | 443 | HTTPS | ELB API for load balancers |
| `autoscaling.amazonaws.com` | 443 | HTTPS | Auto Scaling API |
| `sts.amazonaws.com` | 443 | HTTPS | AWS Security Token Service (STS) |
| `iam.amazonaws.com` | 443 | HTTPS | IAM API for authentication |
| `logs.amazonaws.com` | 443 | HTTPS | CloudWatch Logs |
| `monitoring.amazonaws.com` | 443 | HTTPS | CloudWatch Metrics |
| `*.s3.amazonaws.com` | 443 | HTTPS | S3 storage access |
| `s3.amazonaws.com` | 443 | HTTPS | S3 API endpoint |
| `*.s3.<region>.amazonaws.com` | 443 | HTTPS | Regional S3 endpoints |

---

## 4. TIBCO Flogo Go Module Proxy (CRITICAL for Flogo Apps)

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

## 5. Monitoring and Observability

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `prometheus.io` | 443 | HTTPS | Prometheus documentation |
| `opentelemetry.io` | 443 | HTTPS | OpenTelemetry documentation |
| `elastic.co` | 443 | HTTPS | Elastic documentation and downloads |
| `grafana.com` | 443 | HTTPS | Grafana documentation and downloads |

---

## 6. Source Code and Documentation

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `github.com` | 443 | HTTPS | GitHub - Source code, releases, documentation |
| `*.githubusercontent.com` | 443 | HTTPS | GitHub raw content |
| `raw.githubusercontent.com` | 443 | HTTPS | GitHub raw file content |
| `ubuntu.com` | 443 | HTTPS | Ubuntu package repositories (for base images) |
| `archive.ubuntu.com` | 443 | HTTPS | Ubuntu package archives |
| `security.ubuntu.com` | 443 | HTTPS | Ubuntu security updates |

---

## 7. TIBCO Platform Documentation (Optional)

| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `https://docs.tibco.com` | 443 | HTTPS | TIBCO Platform official documentation |
| `https://learn.tibco.com` | 443 | HTTPS | TIBCO learning resources |

---

## 8. Internal Cluster Communication (No Firewall Rules Needed)

These are internal cluster services that communicate within the Kubernetes cluster:

- `*.svc.cluster.local` - Internal Kubernetes service DNS
- `otel-userapp-traces.<namespace>.svc.cluster.local` - OTEL trace collector
- `otel-userapp-metrics.<namespace>.svc.cluster.local` - OTEL metrics collector
- `dp-config-es-es-http.elastic-system.svc.cluster.local` - Elasticsearch
- `kube-prometheus-stack-prometheus.prometheus-system.svc.cluster.local` - Prometheus
- `169.254.169.254` - AWS EC2 metadata service (node-local, no external access)

---

## 9. Complete Firewall Rules Summary

### Outbound Rules (From EKS to Internet)

#### Required (CRITICAL)
```
Protocol: HTTPS (443)
Destinations:
  # TIBCO Platform
  - csgprduswrepoedge.jfrog.io              # TIBCO images
  - tibcosoftware.github.io                  # TIBCO helm charts
  
  # Container Registries
  - docker.io                                 # Docker Hub
  - registry-1.docker.io                      # Docker Hub registry
  - ghcr.io                                   # GitHub Container Registry
  - quay.io                                   # Red Hat Quay
  - registry.k8s.io                           # Kubernetes registry
  
  # Helm Repositories
  - charts.jetstack.io                        # cert-manager
  - helm.elastic.co                           # Elastic ECK
  - kubernetes-sigs.github.io                 # External DNS
  - prometheus-community.github.io            # Prometheus stack
  - aws.github.io                             # AWS EKS charts
  
  # AWS Services
  - *.eks.amazonaws.com                       # EKS API
  - *.ecr.<region>.amazonaws.com              # ECR
  - *.dkr.ecr.<region>.amazonaws.com          # ECR Docker
  - ec2.amazonaws.com                         # EC2 API
  - elasticloadbalancing.amazonaws.com        # ELB API
  - sts.amazonaws.com                         # STS
  - iam.amazonaws.com                         # IAM
  
  # Go Module Proxy (for Flogo)
  - proxy.golang.org                          # Go modules
  - sum.golang.org                            # Go checksum database
```

#### Recommended (HIGHLY RECOMMENDED)
```
Protocol: HTTPS (443)
Destinations:
  # AWS Services
  - autoscaling.amazonaws.com                 # Auto Scaling
  - logs.amazonaws.com                        # CloudWatch Logs
  - monitoring.amazonaws.com                  # CloudWatch Metrics
  - s3.amazonaws.com                          # S3 API
  - *.s3.amazonaws.com                        # S3 buckets
  - *.s3.<region>.amazonaws.com               # Regional S3
  - public.ecr.aws                            # ECR Public
  
  # Container Registries
  - gcr.io                                    # Google Container Registry
  - k8s.gcr.io                                # Kubernetes legacy registry
  
  # Source Control
  - github.com                                # GitHub
  - *.githubusercontent.com                   # GitHub raw content
  - raw.githubusercontent.com                 # GitHub raw files
```

#### Optional (For Documentation and Troubleshooting)
```
Protocol: HTTPS (443)
Destinations:
  - kubernetes.io                             # Kubernetes docs
  - k8s.io                                    # Kubernetes
  - docs.tibco.com                            # TIBCO docs
  - learn.tibco.com                           # TIBCO learning
  - prometheus.io                             # Prometheus docs
  - opentelemetry.io                          # OpenTelemetry docs
  - elastic.co                                # Elastic docs
  - grafana.com                               # Grafana docs
  - ubuntu.com                                # Ubuntu packages
  - archive.ubuntu.com                        # Ubuntu archives
  - security.ubuntu.com                       # Ubuntu security
```

---

## 10. AWS Security Group Rules

If using AWS Security Groups, create the following outbound rules:

### Priority 100: TIBCO Container Registry
```
Type: HTTPS
Protocol: TCP
Port Range: 443
Destination: 0.0.0.0/0
Description: Allow TIBCO JFrog container registry
```

### Priority 110: Helm Chart Repositories
```
Type: HTTPS
Protocol: TCP
Port Range: 443
Destination: 0.0.0.0/0
Description: Allow Helm chart repositories
```

### Priority 120: AWS Services
```
Type: HTTPS
Protocol: TCP
Port Range: 443
Destination: com.amazonaws.<region>.s3 (VPC Endpoint)
Description: Allow S3 via VPC endpoint (if configured)
```

### Priority 130: Go Module Proxy (Flogo)
```
Type: HTTPS
Protocol: TCP
Port Range: 443
Destination: 0.0.0.0/0
Description: Allow Go module proxy for Flogo applications
```

**Note**: For better security, use VPC endpoints for AWS services where possible.

---

## 11. AWS Network Firewall Rules

If using AWS Network Firewall, create the following rules:

### Stateful Domain List Rule Group: TIBCO-Platform-Required
```yaml
Rule Group Type: Stateful Domain List
Capacity: 100
Rules:
  # TIBCO Platform
  - Domain: .jfrog.io
    Action: ALLOW
    Protocol: HTTPS
  
  - Domain: tibcosoftware.github.io
    Action: ALLOW
    Protocol: HTTPS
  
  # Container Registries
  - Domain: .docker.io
    Action: ALLOW
    Protocol: HTTPS
  
  - Domain: ghcr.io
    Action: ALLOW
    Protocol: HTTPS
  
  - Domain: quay.io
    Action: ALLOW
    Protocol: HTTPS
  
  - Domain: registry.k8s.io
    Action: ALLOW
    Protocol: HTTPS
  
  # Helm Repositories
  - Domain: .github.io
    Action: ALLOW
    Protocol: HTTPS
  
  - Domain: charts.jetstack.io
    Action: ALLOW
    Protocol: HTTPS
  
  - Domain: helm.elastic.co
    Action: ALLOW
    Protocol: HTTPS
  
  # AWS Services
  - Domain: .amazonaws.com
    Action: ALLOW
    Protocol: HTTPS
  
  - Domain: .eks.amazonaws.com
    Action: ALLOW
    Protocol: HTTPS
  
  # Go Module Proxy (Flogo)
  - Domain: proxy.golang.org
    Action: ALLOW
    Protocol: HTTPS
  
  - Domain: sum.golang.org
    Action: ALLOW
    Protocol: HTTPS
```

---

## 12. VPC Endpoints (Recommended for AWS Services)

To reduce data transfer costs and improve security, configure VPC endpoints for AWS services:

### Interface Endpoints (PrivateLink)
```
- com.amazonaws.<region>.ec2
- com.amazonaws.<region>.ecr.api
- com.amazonaws.<region>.ecr.dkr
- com.amazonaws.<region>.sts
- com.amazonaws.<region>.logs
- com.amazonaws.<region>.monitoring
- com.amazonaws.<region>.autoscaling
- com.amazonaws.<region>.elasticloadbalancing
```

### Gateway Endpoints
```
- com.amazonaws.<region>.s3
```

**Benefits**:
- Traffic stays within AWS network
- No internet gateway required for AWS services
- Reduced data transfer costs
- Enhanced security

---

## 13. DNS Requirements

Ensure the following DNS resolutions work from within the EKS cluster:

### External DNS
- `csgprduswrepoedge.jfrog.io`
- `tibcosoftware.github.io`
- `docker.io`
- `registry-1.docker.io`
- `ghcr.io`
- `proxy.golang.org` (for Flogo)
- `sum.golang.org` (for Flogo)

### AWS-Specific DNS
- `*.eks.amazonaws.com`
- `*.ecr.<region>.amazonaws.com`
- `s3.amazonaws.com`
- `*.s3.amazonaws.com`

### Internal DNS (CoreDNS)
- `*.svc.cluster.local` (internal service discovery)
- `169.254.169.254` (EC2 metadata - node-local)

---

## 14. Testing Connectivity

After configuring firewall rules, test connectivity from within the EKS cluster:

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

# Test ECR
kubectl run test-ecr --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://public.ecr.aws
```

### Test Helm Repository Access
```bash
# Test TIBCO Helm charts
kubectl run test-helm --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://tibcosoftware.github.io/tp-helm-charts/index.yaml

# Test cert-manager charts
kubectl run test-certmgr --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://charts.jetstack.io/index.yaml

# Test AWS EKS charts
kubectl run test-eks-charts --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://aws.github.io/eks-charts/index.yaml
```

### Test AWS Connectivity
```bash
# Test AWS STS
kubectl run test-sts --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://sts.amazonaws.com

# Test S3
kubectl run test-s3 --image=curlimages/curl --rm -it --restart=Never -- \
  curl -I https://s3.amazonaws.com
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

## 15. Proxy Configuration for Enterprise Environments

If your enterprise has a secure HTTP/HTTPS proxy already configured, you can configure TIBCO Platform to use it instead of opening all firewall rules.

### 15.1 Prerequisites

- HTTP/HTTPS proxy server already deployed and operational
- Proxy allows HTTPS traffic to required endpoints (see sections above)
- Proxy authentication credentials (if required)

### 15.2 Configure EKS Nodes for Proxy

Configure proxy settings on EKS nodes using user data or launch templates:

```bash
# /etc/environment or /etc/profile.d/proxy.sh
export HTTP_PROXY="http://proxy.company.com:8080"
export HTTPS_PROXY="http://proxy.company.com:8080"
export NO_PROXY="localhost,127.0.0.1,169.254.169.254,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,.internal,.svc,.svc.cluster.local,<EKS_SERVICE_CIDR>,<EKS_POD_CIDR>,.amazonaws.com"

# Lowercase versions (some applications require these)
export http_proxy="$HTTP_PROXY"
export https_proxy="$HTTPS_PROXY"
export no_proxy="$NO_PROXY"
```

**NO_PROXY must include**:
- `localhost`, `127.0.0.1` - Local host
- `169.254.169.254` - AWS EC2 metadata service
- `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` - Private IP ranges
- `.internal` - AWS internal DNS
- `.svc`, `.svc.cluster.local` - Kubernetes service discovery
- `<EKS_SERVICE_CIDR>` - Your EKS service CIDR (e.g., `10.100.0.0/16`)
- `<EKS_POD_CIDR>` - Your EKS pod CIDR (e.g., `10.244.0.0/16`)
- `.amazonaws.com` - AWS service endpoints (use VPC endpoints instead)

### 15.3 Configure TIBCO Platform Control Plane Proxy Settings

After installing the TIBCO Platform Control Plane, configure proxy settings through the UI or via Helm values.

**Reference Documentation**: [TIBCO Platform - Updating Proxy Configuration](https://docs.tibco.com/pub/platform-cp/1.14.0/doc/html/Default.htm#UserGuide/updating-proxy-configuration.htm)

#### Option 1: Configure via Control Plane UI

1. Login to TIBCO Platform Control Plane UI
2. Navigate to **Settings** → **Infrastructure** → **Proxy Configuration**
3. Configure the following settings:

```yaml
HTTP Proxy: http://proxy.company.com:8080
HTTPS Proxy: http://proxy.company.com:8080
No Proxy: localhost,127.0.0.1,.svc,.svc.cluster.local,.internal,169.254.169.254,10.0.0.0/8
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
      noProxy: "localhost,127.0.0.1,.svc,.svc.cluster.local,.internal,169.254.169.254,10.0.0.0/8"
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

### 15.4 Configure TIBCO Platform Data Plane Proxy Settings

Configure proxy settings for the Data Plane similarly:

```yaml
# dp-configure-namespace values
global:
  tibco:
    proxy:
      enabled: true
      httpProxy: "http://proxy.company.com:8080"
      httpsProxy: "http://proxy.company.com:8080"
      noProxy: "localhost,127.0.0.1,.svc,.svc.cluster.local,.internal,169.254.169.254,10.0.0.0/8"
```

### 15.5 Configure Flogo Applications for Go Module Proxy

For TIBCO Flogo applications that are NOT built using the Flogo CLI, configure the Go module proxy:

#### Option 1: Use Corporate Proxy for proxy.golang.org

Ensure your corporate proxy allows access to:
- `https://proxy.golang.org`
- `https://sum.golang.org`

No additional configuration needed if EKS nodes are already configured with proxy settings.

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

### 15.6 Verify Proxy Configuration

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

### 15.7 Proxy Configuration Best Practices

1. **Use HTTPS proxy** if available for encrypted traffic
2. **Configure NO_PROXY carefully** to avoid routing internal traffic through proxy
3. **Test thoroughly** after proxy configuration changes
4. **Monitor proxy logs** for blocked connections or authentication issues
5. **Document proxy exceptions** required for TIBCO Platform
6. **Use VPC endpoints** for AWS services to bypass proxy
7. **Rotate proxy credentials** regularly if authentication is required

### 15.8 Troubleshooting Proxy Issues

**Issue**: Pods cannot pull images through proxy
```bash
# Check containerd/docker proxy configuration on nodes
systemctl show containerd --property Environment
systemctl show docker --property Environment

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

## 16. Simplified Firewall Request Template for EKS

For enterprise environments with strict firewall policies, use this template to submit a firewall request.

### Generic Internet Access on Port 443 (Recommended Approach)

**Request Type**: Outbound Internet Access  
**Protocol**: HTTPS  
**Port**: 443  
**Direction**: Outbound (from EKS cluster to Internet)

#### Option 1: Broad Access (Simplest)

```
Source: <EKS_SUBNET_CIDR> (e.g., 10.0.0.0/16)
Destination: Any (0.0.0.0/0)
Port: 443
Protocol: TCP
Action: Allow
Justification: Required for TIBCO Platform deployment - container image pulls, 
helm chart downloads, Go module proxy access, and AWS API access
```

**Pros**: Covers all required and optional endpoints  
**Cons**: Less secure, may not meet compliance requirements  
**Use Case**: Development/test environments, PoC deployments

#### Option 2: AWS Service-Based (Recommended)

```yaml
Source: <EKS_SUBNET_CIDR>
Destinations:
  - 0.0.0.0/0 (Internet) for TIBCO JFrog, Helm repos, Docker Hub, GitHub, Go Proxy
  - Use VPC Endpoints for AWS services (S3, ECR, STS, EC2, etc.)
Port: 443
Protocol: TCP
Action: Allow
```

**Pros**: Better security using VPC endpoints for AWS services  
**Cons**: Requires VPC endpoint setup  
**Use Case**: Production environments

#### Option 3: FQDN-Based (Most Secure)

For maximum security, request access to specific FQDNs only:

```yaml
Rule Name: TIBCO-Platform-EKS-HTTPS-Access
Source: <EKS_SUBNET_CIDR>
Destination Type: FQDN
Port: 443
Protocol: HTTPS

Required FQDNs (CRITICAL - Must be approved):
  - csgprduswrepoedge.jfrog.io          # TIBCO container images
  - tibcosoftware.github.io              # TIBCO helm charts
  - docker.io                            # Docker Hub
  - registry-1.docker.io                 # Docker Hub registry
  - ghcr.io                              # GitHub Container Registry
  - quay.io                              # Red Hat Quay
  - registry.k8s.io                      # Kubernetes registry
  - charts.jetstack.io                   # cert-manager
  - helm.elastic.co                      # Elastic ECK
  - kubernetes-sigs.github.io            # External DNS
  - prometheus-community.github.io       # Prometheus
  - aws.github.io                        # AWS EKS charts
  - proxy.golang.org                     # Go module proxy (Flogo)
  - sum.golang.org                       # Go checksum database (Flogo)
  - *.eks.amazonaws.com                  # EKS API
  - *.ecr.<region>.amazonaws.com         # ECR
  - *.dkr.ecr.<region>.amazonaws.com     # ECR Docker
  - ec2.amazonaws.com                    # EC2 API
  - elasticloadbalancing.amazonaws.com   # ELB API
  - sts.amazonaws.com                    # STS
  - iam.amazonaws.com                    # IAM

Optional FQDNs (Recommended):
  - github.com                           # Source code and releases
  - *.githubusercontent.com              # GitHub raw content
  - public.ecr.aws                       # ECR Public
  - s3.amazonaws.com                     # S3 API
  - *.s3.amazonaws.com                   # S3 buckets
  - gcr.io                               # Google Container Registry
  - docs.tibco.com                       # TIBCO documentation
```

**Pros**: Most secure, explicit FQDN allow-list  
**Cons**: Requires AWS Network Firewall with FQDN filtering  
**Use Case**: Production environments with strict security requirements

---

## 17. Troubleshooting

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

**Issue**: Flogo applications fail to start with Go module errors
**Solution**:
1. **Most Common**: Verify access to `proxy.golang.org` and `sum.golang.org`
2. Check pod logs: `kubectl logs <flogo-pod> | grep -i "proxy.golang.org"`
3. Verify GOPROXY environment variable: `kubectl exec <flogo-pod> -- env | grep GOPROXY`
4. **Workaround**: Build Flogo applications using Flogo CLI to bundle dependencies

**Issue**: AWS EBS CSI driver not working
**Solution**:
1. Ensure access to `ec2.amazonaws.com`
2. Verify IAM role has correct permissions for EBS
3. Check driver logs: `kubectl logs -n kube-system -l app=ebs-csi-controller`

**Issue**: cert-manager certificates not issuing
**Solution**:
1. Verify access to `charts.jetstack.io` for initial installation
2. For Let's Encrypt, ensure outbound port 80/443 to Let's Encrypt ACME servers
3. Check cert-manager logs: `kubectl logs -n cert-manager -l app=cert-manager`

**Issue**: Unable to pull images from ECR
**Solution**:
1. Verify access to `*.ecr.<region>.amazonaws.com` and `*.dkr.ecr.<region>.amazonaws.com`
2. Check IAM role for service account (IRSA) configuration
3. Verify ECR repository policy
4. Test with: `aws ecr get-login-password --region <region>`

---

## 18. Security Considerations

### Least Privilege Access
- Only allow outbound traffic to required destinations
- Use VPC endpoints for AWS services to avoid internet egress
- Implement Network Policies within the cluster
- Use AWS PrivateLink for third-party services where possible

### Credential Management
- Store JFrog credentials in AWS Secrets Manager
- Use IAM Roles for Service Accounts (IRSA) for AWS service authentication
- Rotate credentials regularly
- Never hardcode credentials in Helm values or code

### Monitoring
- Enable VPC Flow Logs
- Enable AWS Network Firewall logging
- Set up CloudWatch alarms for blocked connections
- Monitor proxy logs (if using corporate proxy)

### Compliance
- Document all allowed endpoints for audit purposes
- Regularly review and update firewall rules
- Implement change management for firewall rule modifications
- Maintain least privilege access principles

---

## 19. References

- [TIBCO Platform Helm Charts](https://github.com/TIBCOSoftware/tp-helm-charts)
- [TIBCO Platform Proxy Configuration](https://docs.tibco.com/pub/platform-cp/1.14.0/doc/html/Default.htm#UserGuide/updating-proxy-configuration.htm)
- [Amazon EKS Network Requirements](https://docs.aws.amazon.com/eks/latest/userguide/network_reqs.html)
- [AWS Network Firewall](https://docs.aws.amazon.com/network-firewall/latest/developerguide/what-is-aws-network-firewall.html)
- [AWS VPC Endpoints](https://docs.aws.amazon.com/vpc/latest/privatelink/vpc-endpoints.html)
- [Go Module Proxy](https://proxy.golang.org)
- [AWS EKS Best Practices - Networking](https://aws.github.io/aws-eks-best-practices/networking/index/)

---

**Document Version**: 1.0  
**Last Updated**: January 29, 2026  
**Cloud Provider**: Amazon Web Services (AWS)  
**Generated For**: TIBCO Platform on EKS deployment

