# Firewall Requirements for TIBCO Platform Helm Charts Deployment on AKS

This document lists all external URLs and endpoints that need to be accessible for deploying TIBCO Platform on Azure Kubernetes Service using the tp-helm-charts repository.

**Repository**: https://github.com/TIBCOSoftware/tp-helm-charts  
**Generated**: January 23, 2026

---

## Summary

The TIBCO Platform deployment requires access to:
- **7 Container Registries** for pulling images
- **5 Helm Chart Repositories** for downloading charts
- **8+ External Services** for Kubernetes, monitoring, and documentation
- **3 Azure-specific endpoints** for storage and management

---

## 1. Container Registries

These registries host the container images used by TIBCO Platform and its dependencies.

### TIBCO Container Registry (CRITICAL)
| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `csgprduswrepoedge.jfrog.io` | 443 | HTTPS | **PRIMARY**: TIBCO Platform production images (CP, DP, capabilities) |

> [!IMPORTANT]
> This is the main TIBCO container registry. Access requires authentication with JFrog credentials.

### Public Container Registries
| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `docker.io` | 443 | HTTPS | Docker Hub - Third-party and open-source images |
| `ghcr.io` | 443 | HTTPS | GitHub Container Registry - Community images |
| `k8s.io` | 443 | HTTPS | Kubernetes official images |
| `kubernetes.io` | 443 | HTTPS | Kubernetes documentation and tools |

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

### Kubernetes API Endpoints
| URL | Port | Protocol | Purpose |
|-----|------|----------|---------|
| `kubernetes.io` | 443 | HTTPS | Kubernetes documentation and API references |
| `k8s.io` | 443 | HTTPS | Kubernetes package repositories |

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
  - docker.io                                 # Docker Hub
  - ghcr.io                                   # GitHub Container Registry
  - charts.jetstack.io                        # cert-manager
  - helm.elastic.co                           # Elastic ECK
  - kubernetes-sigs.github.io                 # External DNS
  - prometheus-community.github.io            # Prometheus stack
  - management.azure.com                      # Azure ARM
  - login.microsoftonline.com                 # Azure AD
  - disk.csi.azure.com                        # Azure Disk CSI
  - file.csi.azure.com                        # Azure Files CSI
```

#### Recommended (HIGHLY RECOMMENDED)
```
Protocol: HTTPS (443)
Destinations:
  - mcr.microsoft.com                         # Microsoft Container Registry
  - *.azurecr.io                              # Azure Container Registry
  - k8s.io                                    # Kubernetes
  - kubernetes.io                             # Kubernetes
  - github.com                                # GitHub
  - *.githubusercontent.com                   # GitHub raw content
  - *.blob.core.windows.net                   # Azure Blob Storage
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
```

---

## 10. Proxy Configuration

If using an HTTP proxy, configure the following environment variables on AKS nodes:

```bash
export HTTP_PROXY="http://proxy.company.com:8080"
export HTTPS_PROXY="http://proxy.company.com:8080"
export NO_PROXY="localhost,127.0.0.1,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16,*.svc,*.svc.cluster.local,<AKS_SERVICE_CIDR>,<AKS_POD_CIDR>"
```

**NO_PROXY must include**:
- Cluster service CIDR (e.g., `10.0.0.0/16`)
- Cluster pod CIDR (e.g., `10.244.0.0/16`)
- `.svc` and `.svc.cluster.local` for internal service discovery
- Azure metadata service: `169.254.169.254`

---

## 11. DNS Requirements

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

## 12. Testing Connectivity

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

---

## 13. Troubleshooting

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

---

## 14. Security Considerations

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

## 15. References

- [TIBCO Platform Helm Charts](https://github.com/TIBCOSoftware/tp-helm-charts)
- [Azure Kubernetes Service Network Concepts](https://learn.microsoft.com/en-us/azure/aks/concepts-network)
- [Azure Firewall Application Rules](https://learn.microsoft.com/en-us/azure/firewall/rule-processing)
- [AKS Outbound Network Rules](https://learn.microsoft.com/en-us/azure/aks/limit-egress-traffic)

---

**Document Version**: 1.0  
**Last Updated**: January 23, 2026  
**Generated From**: /Users/kul/git/tib/tp-helm-charts
