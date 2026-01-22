# TIBCO Platform on AKS - Customer Prerequisites Checklist

**Document Purpose**: This checklist outlines the requirements that must be in place **before** TIBCO Platform Control Plane and Data Plane installation begins on Azure Kubernetes Service (AKS).

**Target Audience**: Customer IT teams responsible for Azure infrastructure preparation

**Last Updated**: January 22, 2026

---

## Overview

Before TIBCO implementation team arrives on-site or begins remote installation, please ensure all prerequisites listed in this document are met. This preparation is critical for a successful and timely deployment.

**Estimated Preparation Time**: 3-5 business days (depending on organizational processes)

---

## 1. Azure Kubernetes Service (AKS) Cluster Requirements

> **Note**: TIBCO Control Plane supports Cloud Native Computing Foundation (CNCF) certified Kubernetes platforms.

### Control Plane AKS Cluster

| Requirement | Specification | Notes |
|-------------|--------------|-------|
| **Cluster Type** | Azure Kubernetes Service (AKS) | CNCF certified |
| **Kubernetes Version** | 1.32 or higher | Please refer to [AKS supported versions](https://learn.microsoft.com/en-us/azure/aks/supported-kubernetes-versions) |
| **Cluster Access** | `kubectl` CLI with admin permissions | Must be able to create namespaces, CRDs, and cluster roles |
| **Node Pools** | Minimum 3 worker nodes | For high availability |
| **Node SKU** | Standard_D8s_v3 or higher | Control Plane is resource-intensive |
| **Total Cluster Capacity** | 24+ CPU cores, 96+ GB RAM | Ensure sufficient headroom for Control Plane workloads |
| **Network Plugin** | Azure CNI or Kubenet | Azure CNI recommended for advanced networking |
| **Network Policy** | Calico (optional) | For production security requirements |
| **Kubernetes API Access** | Stable network connectivity | Required for helm operations |

### Data Plane AKS Cluster(s)

| Requirement | Specification | Notes |
|-------------|--------------|-------|
| **Cluster Type** | Azure Kubernetes Service (AKS) | Can be same cluster as Control Plane for dev/test |
| **Kubernetes Version** | 1.32 or higher | Must match or be compatible with Control Plane |
| **Cluster Access** | `kubectl` CLI with admin permissions | Per Data Plane cluster |
| **Node SKU** | Standard_D4s_v3 or higher | Based on workload requirements |
| **Node Resources** | Minimum 4 CPU cores, 16 GB RAM per node | Scale based on capability needs |
| **Network Connectivity** | Bidirectional HTTPS to Control Plane | See network requirements section |

### AKS Cluster Configuration

| Configuration | Requirement | Details |
|--------------|-------------|---------|
| **VNet CIDR** | Sufficient IP address space | e.g., `10.4.0.0/16` |
| **Subnet CIDR** | AKS subnet with adequate IPs | e.g., `10.4.0.0/20` |
| **Service CIDR** | Kubernetes service IPs | e.g., `10.0.0.0/16` |
| **DNS Service IP** | Within service CIDR | e.g., `10.0.0.10` |
| **Resource Group** | Dedicated Azure resource group | For AKS and related resources |

---

## 2. Access and Credentials

### Required Azure Access

| Access Type | Details | Must Have Before Installation |
|-------------|---------|------------------------------|
| **Azure Subscription** | Owner or Contributor role | ✅ Required |
| **AKS Cluster Admin** | Azure Kubernetes Service RBAC Cluster Admin | ✅ Required |
| **Container Registry** | Pull credentials for TIBCO images | ✅ Required |
| **DNS Management** | Ability to create DNS records in Azure DNS | ✅ Required for Control Plane |
| **Certificate Authority** | Ability to request/generate SSL certificates | ✅ Required for Control Plane |
| **PostgreSQL Admin** | Database admin credentials | ✅ Required for Control Plane |

### Tools Required on Installation Machine

| Tool | Version | Purpose |
|------|---------|---------|
| `az` (Azure CLI) | 2.50.0+ | Azure resource management |
| `kubectl` | Latest stable | Kubernetes cluster management |
| `helm` | 3.17.0+ | Chart deployment |
| `openssl` | 1.1+ | Certificate generation |
| `curl` / `wget` | Latest | Download scripts and charts |
| `jq` | 1.6+ | JSON processing (optional but recommended) |
| `git` | Latest | Clone repositories (if needed) |

---

## 3. Network Requirements

### Control Plane Network Requirements

| Network Configuration | Requirement | Details |
|----------------------|-------------|---------|
| **Internet Access** | Outbound HTTPS (443) | To pull container images from TIBCO registry |
| **DNS Resolution** | Internal and external | Must resolve both cluster services and internet domains |
| **Load Balancer** | Azure Load Balancer | Automatically provisioned by AKS |
| **Firewall Rules** | Allow required ports | See port table below |
| **VNet Peering** | Optional (NOT required with DNS) | CP and DP communicate over secure tunnels via DNS entries. VNet peering only needed for private/internal-only scenarios without DNS |

### Data Plane Network Requirements

| Network Configuration | Requirement | Details |
|----------------------|-------------|---------|
| **Control Plane Connectivity** | HTTPS (443) to CP domains | Both `my` and `tunnel` domains via DNS |
| **Internet Access** | Outbound HTTPS (443) | To pull container images |
| **DNS Resolution** | **REQUIRED** - Internal and external | Must resolve Control Plane domains. CP and DP communicate via secure tunnels using DNS |
| **Application Ingress** | DNS records for BWCE/Flogo apps | Capabilities use ingress controllers registered in DNS for external access |
| **VNet Configuration** | Proper subnet sizing | Sufficient IPs for pods and services |

### Required Network Ports

| Source | Destination | Port | Protocol | Purpose |
|--------|------------|------|----------|---------|
| User Browser | Control Plane Ingress | 443 | HTTPS | Control Plane UI access |
| Data Plane | Control Plane (`my` domain) | 443 | HTTPS | Platform API communication |
| Data Plane | Control Plane (`tunnel` domain) | 443 | HTTPS | Hybrid connectivity |
| Control Plane Pods | PostgreSQL | 5432 | TCP | Database access |
| Control Plane Pods | Container Registry | 443 | HTTPS | Image pulls |
| AKS Nodes | Azure Storage | 443/445 | HTTPS/SMB | Azure Files access |

### Network Security Groups (NSGs)

Ensure NSGs allow:
- [ ] Outbound HTTPS (443) from AKS subnet to internet
- [ ] Inbound HTTPS (443) to Load Balancer public IP
- [ ] PostgreSQL (5432) from AKS subnet to database
- [ ] Azure Storage access (443, 445) for Azure Files/Disk

---

## 4. Storage Requirements

### Azure Storage Configuration

AKS uses Azure-managed storage with two primary types:

#### Azure Disk (Premium_LRS)

**Use Cases:**
- PostgreSQL database persistent volumes
- EMS (Enterprise Message Service) data volumes
- Developer Hub persistent storage

**Specifications:**
| Parameter | Value | Notes |
|-----------|-------|-------|
| **Storage Class** | `azure-disk-sc` (Premium_LRS) | For high-performance workloads |
| **Access Mode** | ReadWriteOnce (RWO) | Block storage |
| **Provisioner** | `disk.csi.azure.com` | Azure Disk CSI driver |
| **Reclaim Policy** | Delete (default) or Retain | Retain for production EMS |
| **Volume Binding Mode** | WaitForFirstConsumer or Immediate | WaitForFirstConsumer recommended |

#### Azure Files (Premium_LRS or Standard_LRS)

**Use Cases:**
- BusinessWorks Container Edition (BWCE) shared storage
- Artifact Manager storage
- Shared configuration files

**Specifications:**
| Parameter | Value | Notes |
|-----------|-------|-------|
| **Storage Class** | `azure-files-sc` | Premium_LRS for production |
| **Access Mode** | ReadWriteMany (RWX) | Shared file storage |
| **Provisioner** | `file.csi.azure.com` | Azure Files CSI driver |
| **Network Endpoint** | Private Endpoint (recommended) | For security |
| **Mount Options** | `mfsymlinks`, `cache=strict`, `nosharesock` | For compatibility |

### Storage Account Requirements

| Requirement | Specification | Critical Notes |
|-------------|--------------|----------------|
| **Storage Account** | Existing or new Azure Storage Account | Required for Azure Files |
| **Storage Account Name** | Must be unique across Azure | 3-24 characters, lowercase alphanumeric |
| **Storage Account Resource Group** | Known resource group | For Azure Files share creation |
| **Access Tier** | Hot (recommended) | For frequently accessed data |
| **Replication** | LRS, ZRS, or GRS | Based on durability requirements |
| **Network Access** | Private endpoint or selected networks | Restrict public access |

### Control Plane Storage

| Storage Type | Size | Performance | Use Case | Storage Class Required |
|--------------|------|-------------|----------|----------------------|
| **Azure Files** | 100 GB | Premium_LRS | Shared configurations, logs | `azure-files-sc` |
| **Azure Disk** | 50 GB | Premium_LRS | PostgreSQL database (if in-cluster) | `azure-disk-sc` |

### Data Plane Storage

| Storage Type | Size | Performance | Use Case | Storage Class Required |
|--------------|------|-------------|----------|----------------------|
| **Azure Files** | 50 GB per namespace | Premium or Standard_LRS | BWCE application deployments | `azure-files-sc` |
| **Azure Disk** | As needed | Premium_LRS | EMS persistent storage | `azure-disk-sc` |

### Storage Class Verification

**Must be completed before installation:**

```bash
# Verify storage classes exist
kubectl get storageclass

# Expected output should include:
# - azure-disk-sc (Premium_LRS, disk.csi.azure.com)
# - azure-files-sc (Premium_LRS, file.csi.azure.com)
```

### Required Storage Account Information

- [ ] Storage Account Name: `_______________________`
- [ ] Storage Account Resource Group: `_______________________`
- [ ] Storage Account Access Key: `_______________________` (stored securely)
- [ ] VNet integration configured (if using private endpoints)

---

## 5. PostgreSQL Database (Control Plane Only)

### Database Requirements

| Requirement | Specification | Critical Notes |
|-------------|--------------|----------------|
| **Version** | PostgreSQL 16 | Must be version 16 |
| **Database Size** | 50 GB initial, 200 GB recommended | Grows with platform usage |
| **Connection Limit** | Minimum 100 concurrent connections | Default PostgreSQL is 100 |
| **Extensions Required** | `uuid-ossp` | **Must be enabled before installation** |
| **Network Access** | Accessible from AKS pods | Port 5432 (default) |
| **Credentials** | Master user with database creation privileges | Required for schema setup |
| **SSL/TLS** | Enforced for Azure PostgreSQL | Azure provides server certificates |

### Database Naming Convention Restrictions

> **⚠️ CRITICAL REQUIREMENT**
> 
> The `controlPlaneInstanceId` (e.g., `cp1`) is used as a database name prefix. PostgreSQL identifiers **CANNOT contain hyphens (-)**.
>
> **Valid Instance ID examples**: `cp1`, `nxpcp`, `nxp_tibco_cp`, `prod1`  
> **Invalid examples**: `nxp-tibco-cp` ❌, `my-control-plane` ❌
>
> **Databases created**: `{instanceId}_tscidmdb`, `{instanceId}_defaultidpdb`, etc.

### Database Options for AKS

#### Option 1: Azure Database for PostgreSQL Flexible Server (Recommended for Production)

**Specifications:**
| Parameter | Recommendation | Notes |
|-----------|---------------|-------|
| **SKU** | General Purpose or Memory Optimized | Based on workload |
| **Compute Size** | 4 vCores, 16 GB RAM minimum | Start with D4s_v3 equivalent |
| **Storage** | 128 GB Premium SSD minimum | Auto-grow enabled |
| **High Availability** | Zone-redundant HA (optional) | For production environments |
| **Backup** | 7-30 days retention | Automated backups |
| **SSL Enforcement** | Required | Azure enforces SSL by default |
| **Server Parameters** | `max_connections = 100` minimum | Adjust based on load |
| **Firewall Rules** | Allow AKS subnet CIDR | Or use VNet integration |
| **Private Endpoint** | Recommended | For secure connectivity |

**Network Configuration:**
- [ ] VNet integration configured OR firewall rules allow AKS subnet
- [ ] Private endpoint created (recommended)
- [ ] DNS resolution configured for private endpoint

#### Option 2: PostgreSQL Deployed in AKS Cluster

**Not recommended for production**, but acceptable for dev/test:
- TIBCO provides Helm chart for PostgreSQL
- Uses Azure Disk storage class
- Single pod, no high availability
- Suitable for workshops and evaluation only

### Required Database Information

Please provide the following **before installation day**:

- [ ] Database host/endpoint: `_______________________` (e.g., `myserver.postgres.database.azure.com`)
- [ ] Database port: `_______________________` (default: 5432)
- [ ] Database name: `_______________________` (typically: `postgres`)
- [ ] Master username: `_______________________` (e.g., `adminuser`)
- [ ] Master password: `_______________________` (stored securely in Azure Key Vault recommended)
- [ ] SSL mode: `require` (Azure enforces SSL)
- [ ] SSL root certificate: Download from Azure Portal (BaltimoreCyberTrustRoot.crt.pem)

### Azure PostgreSQL SSL Certificate

For Azure Database for PostgreSQL:
```bash
# Download SSL certificate
curl -o BaltimoreCyberTrustRoot.crt.pem \
  https://www.digicert.com/CACerts/BaltimoreCyberTrustRoot.crt.pem
```

---

## 6. DNS and Domain Requirements (Control Plane)

### Azure DNS Zones Required

| DNS Zone Purpose | Pattern | Example | DNS Records Needed |
|-----------------|---------|---------|-------------------|
| **Control Plane UI** | `{instanceId}-my.{domain}` | `cp1-my.azure.example.com` | Wildcard or specific A/CNAME |
| **Hybrid Connectivity** | `{instanceId}-tunnel.{domain}` | `cp1-tunnel.azure.example.com` | Wildcard or specific A/CNAME |

### Azure DNS Configuration

| Requirement | Details |
|-------------|---------|
| **Azure DNS Zone** | Public Azure DNS zone created | e.g., `azure.example.com` |
| **Resource Group** | DNS zone resource group | For DNS record management |
| **DNS Zone Access** | Contributor role on DNS zone | To create A/CNAME records |
| **Name Servers** | Domain delegated to Azure DNS | NS records configured at registrar |

### DNS Management Access

- [ ] Can create DNS A or CNAME records in Azure DNS zones
- [ ] DNS propagation time acceptable (typically < 5 minutes with Azure DNS)
- [ ] DNS zones support wildcard records OR can create specific records

### Wildcard vs Specific DNS Records

**Option 1: Wildcard DNS** (Easier, Recommended)
```
*.cp1-my.azure.example.com → <LoadBalancer-Public-IP>
*.cp1-tunnel.azure.example.com → <LoadBalancer-Public-IP>
```

**Option 2: Specific Hostnames** (Required if wildcards not allowed)
```
admin.cp1-my.azure.example.com → <LoadBalancer-Public-IP>
subscription1.cp1-my.azure.example.com → <LoadBalancer-Public-IP>
subscription2.cp1-my.azure.example.com → <LoadBalancer-Public-IP>
# (Pattern repeats for tunnel domain)
```

**Note**: If wildcard DNS is not allowed, provide list of expected subscription names in advance.

### External DNS (Recommended for Automation)

Install External DNS operator to automatically manage Azure DNS records:
- Automatically creates/updates DNS records when ingress resources are created
- Requires Azure Service Principal or Managed Identity with DNS Zone Contributor role
- Reduces manual DNS management overhead

Required Information:
- [ ] Azure Tenant ID: `_______________________`
- [ ] Azure Subscription ID: `_______________________`
- [ ] DNS Zone Resource Group: `_______________________`
- [ ] Service Principal Client ID (if using SP): `_______________________`
- [ ] Service Principal Client Secret (if using SP): `_______________________`

---

## 7. SSL/TLS Certificates (Control Plane)

### Certificate Requirements

| Certificate For | Subject Alternative Names (SANs) | Certificate Type |
|----------------|----------------------------------|------------------|
| **Control Plane UI** | See SAN examples below | Standard SSL certificate |
| **Hybrid Connectivity** | See SAN examples below | Standard SSL certificate |

### Certificate SAN Examples

**Option 1: Wildcard Certificates** (Easier, Recommended)
```
DNS: *.cp1-my.azure.example.com
DNS: *.cp1-tunnel.azure.example.com
```

**Option 2: Specific Hostnames** (If wildcards not allowed by PKI policy)
```
DNS: admin.cp1-my.azure.example.com
DNS: subscription1.cp1-my.azure.example.com
DNS: subscription2.cp1-my.azure.example.com
DNS: admin.cp1-tunnel.azure.example.com
DNS: subscription1.cp1-tunnel.azure.example.com
DNS: subscription2.cp1-tunnel.azure.example.com
```

### Azure Certificate Options

#### Option 1: Azure Key Vault Certificates (Recommended)

Store certificates in Azure Key Vault for security:
- [ ] Azure Key Vault created
- [ ] Certificates imported or generated in Key Vault
- [ ] AKS has access to Key Vault (via managed identity or Service Principal)
- [ ] CSI Secret Store driver installed in AKS (for certificate sync)

#### Option 2: Cert-Manager with Let's Encrypt

For non-production environments:
- [ ] Cert-manager installed in AKS cluster
- [ ] Let's Encrypt ClusterIssuer configured
- [ ] Azure DNS solver configured for domain validation
- [ ] Certificates automatically managed by cert-manager

#### Option 3: Manual Certificate Management

- [ ] Certificates obtained from internal PKI or commercial CA
- [ ] Certificates in PEM format
- [ ] Private keys securely stored

### Required Certificate Information

Please provide **before installation day**:

- [ ] Certificate file (PEM format): `_______________________`
- [ ] Private key file (PEM format): `_______________________`
- [ ] Certificate chain/intermediate certificates: `_______________________`
- [ ] Certificate expiration date: `_______________________`
- [ ] Certificate issued by: `_______________________`

### Self-Signed Certificates

- Acceptable for dev/test environments
- TIBCO can generate during installation if needed
- Not recommended for production

---

## 8. Container Registry Access

### TIBCO Container Registry

| Requirement | Details |
|-------------|---------|
| **Registry URL** | Provided by TIBCO (e.g., `csgprdusw2reposaas.jfrog.io`) |
| **Credentials** | Username and password/token provided by TIBCO |
| **Network Access** | Outbound HTTPS (443) from AKS to registry |
| **Image Pull Secret** | Will be created during installation |

### Required Information

- [ ] TIBCO registry URL: `_______________________`
- [ ] Registry username: `_______________________`
- [ ] Registry password/token: `_______________________`
- [ ] Can pull images from registry (test before installation day)

### Network Connectivity Test

```bash
# Test registry access from installation machine
curl -u "username:password" https://<registry-url>/v2/_catalog
```

### Azure Container Registry (Optional)

If mirroring TIBCO images to Azure Container Registry (ACR):
- [ ] ACR created in same region as AKS
- [ ] AKS has pull access to ACR (via managed identity or attach)
- [ ] TIBCO images imported/mirrored to ACR

---

## 9. Kubernetes Secrets (Created During Installation)

The following Kubernetes secrets will be created during the TIBCO Platform installation. Ensure you have the necessary permissions and information ready.

### Control Plane Secrets

#### 1. Container Registry Pull Secret

**Secret Name**: `tibco-container-registry-credentials`  
**Namespace**: `{instanceId}-ns` (Control Plane namespace)  
**Purpose**: Authenticate and pull TIBCO Platform container images from JFrog registry

**Creation Command**:
```bash
kubectl create secret docker-registry tibco-container-registry-credentials \
  --docker-server=<REGISTRY_URL> \
  --docker-username=<REGISTRY_USERNAME> \
  --docker-password=<REGISTRY_PASSWORD> \
  --docker-email=<YOUR_EMAIL> \
  -n <CP_INSTANCE_ID>-ns
```

**Required Information**:
- Registry URL (e.g., `csgprdusw2reposaas.jfrog.io`)
- Registry username (provided by TIBCO)
- Registry password/token (provided by TIBCO)
- Email address

#### 2. Session Keys Secret (Required)

**Secret Name**: `session-keys`  
**Namespace**: `{instanceId}-ns` (Control Plane namespace)  
**Purpose**: Session encryption keys required by router pods and web-server components

**Creation Command**:
```bash
# Generate random 32-character alphanumeric keys
export TSC_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)
export DOMAIN_SESSION_KEY=$(openssl rand -base64 48 | tr -dc A-Za-z0-9 | head -c32)

# Create secret
kubectl create secret generic session-keys -n <CP_INSTANCE_ID>-ns \
  --from-literal=TSC_SESSION_KEY=${TSC_SESSION_KEY} \
  --from-literal=DOMAIN_SESSION_KEY=${DOMAIN_SESSION_KEY}
```

**Keys**:
- `TSC_SESSION_KEY`: 32-character alphanumeric string
- `DOMAIN_SESSION_KEY`: 32-character alphanumeric string

> **⚠️ Important**: This secret is mandatory. Router pods will fail to start if this secret is missing.

#### 3. Database Credentials Secret (Optional - Auto-Created)

**Secret Name**: `{instanceId}-postgres-credential` (customizable)  
**Namespace**: `{instanceId}-ns` (Control Plane namespace)  
**Purpose**: Store PostgreSQL database credentials for Control Plane components

> **ℹ️ Note**: This secret is **automatically created** by the Control Plane helm chart during installation. Manual creation is only needed if using a custom secret name or pre-creating for specific requirements.

**Manual Creation Command** (if needed):
```bash
kubectl create secret generic <SECRET_NAME> \
  --from-literal=db_username=<DB_USERNAME> \
  --from-literal=db_password=<DB_PASSWORD> \
  -n <CP_INSTANCE_ID>-ns
```

**Keys**:
- `db_username`: PostgreSQL master username
- `db_password`: PostgreSQL master password

#### 4. Database SSL Certificate Secret (Azure PostgreSQL)

**Secret Name**: `db-ssl-root-cert` (customizable)  
**Namespace**: `{instanceId}-ns` (Control Plane namespace)  
**Purpose**: SSL certificate for secure PostgreSQL connection to Azure Database for PostgreSQL

**Creation Command**:
```bash
# Download Azure PostgreSQL root certificate
curl -o BaltimoreCyberTrustRoot.crt.pem \
  https://www.digicert.com/CACerts/BaltimoreCyberTrustRoot.crt.pem

# Create secret
kubectl create secret generic db-ssl-root-cert \
  --from-file=db_ssl_root.cert=BaltimoreCyberTrustRoot.crt.pem \
  -n <CP_INSTANCE_ID>-ns
```

> **⚠️ Critical**: The secret key **must** be named `db_ssl_root.cert` (with a dot, not underscore). This is required by TIBCO Platform.

#### 5. TLS/SSL Certificate Secrets for Ingress

**Secret Names**: 
- `tp-certificate-my` (Control Plane UI domain)
- `tp-certificate-tunnel` (Hybrid connectivity domain)

**Namespace**: `{instanceId}-ns` (Control Plane namespace)  
**Purpose**: TLS certificates for HTTPS ingress to Control Plane domains

**Creation Command**:
```bash
# For Control Plane UI domain
kubectl create secret tls tp-certificate-my \
  --cert=<PATH_TO_CERT_FILE> \
  --key=<PATH_TO_KEY_FILE> \
  -n <CP_INSTANCE_ID>-ns

# For tunnel domain
kubectl create secret tls tp-certificate-tunnel \
  --cert=<PATH_TO_CERT_FILE> \
  --key=<PATH_TO_KEY_FILE> \
  -n <CP_INSTANCE_ID>-ns
```

**Required Files**:
- Certificate file (PEM format)
- Private key file (PEM format)

#### 6. Encryption Secret

**Secret Name**: `cporch-encryption-secret`  
**Namespace**: `{instanceId}-ns` (Control Plane namespace)  
**Purpose**: Encryption key for orchestrator component

**Creation Command**:
```bash
# Generate random encryption key
export ENCRYPTION_KEY=$(openssl rand -base64 32)

# Create secret
kubectl create secret generic cporch-encryption-secret -n <CP_INSTANCE_ID>-ns \
  --from-literal=ENCRYPTION_KEY=${ENCRYPTION_KEY}
```

#### 7. SMTP Credentials Secret (Optional)

**Secret Name**: `smtp-credentials` (customizable)  
**Namespace**: `{instanceId}-ns` (Control Plane namespace)  
**Purpose**: SMTP server authentication for email notifications

**Creation Command**:
```bash
kubectl create secret generic smtp-credentials \
  --from-literal=smtp-username=<SMTP_USERNAME> \
  --from-literal=smtp-password=<SMTP_PASSWORD> \
  -n <CP_INSTANCE_ID>-ns
```

### Data Plane Secrets

#### 1. Container Registry Pull Secret

**Secret Name**: `tibco-container-registry-credentials`  
**Namespace**: `{dataplaneId}-ns` (Data Plane namespace)  
**Purpose**: Pull TIBCO Platform images for Data Plane capabilities

**Creation Command**: Same as Control Plane container registry secret (section 9.1)

### Secrets Checklist

Before installation, ensure you have the following information ready to create secrets:

- [ ] **Container Registry Credentials**:
  - [ ] Registry URL
  - [ ] Username
  - [ ] Password/token
  - [ ] Email address

- [ ] **Database Credentials**:
  - [ ] Master username
  - [ ] Master password
  - [ ] Azure PostgreSQL SSL certificate (BaltimoreCyberTrustRoot.crt.pem)

- [ ] **TLS Certificates**:
  - [ ] Certificate files for `my` domain (PEM format)
  - [ ] Private key files for `my` domain (PEM format)
  - [ ] Certificate files for `tunnel` domain (PEM format)
  - [ ] Private key files for `tunnel` domain (PEM format)

- [ ] **SMTP Credentials** (optional):
  - [ ] SMTP username
  - [ ] SMTP password

> **Note**: Session keys and encryption keys will be generated during installation using `openssl` commands.

### RBAC Requirements for Secret Management

Ensure the installation account has the following permissions in target namespaces:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: tibco-secret-manager
  namespace: <namespace>
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
```

---

## 10. RBAC and Permissions

### AKS Permissions Required

| Resource Type | Operations Needed | Scope |
|--------------|-------------------|-------|
| **Namespaces** | Create, delete, list | Cluster-wide |
| **CRDs** | Create, update, list | Cluster-wide |
| **ClusterRoles** | Create, bind | Cluster-wide |
| **ClusterRoleBindings** | Create, delete | Cluster-wide |
| **ServiceAccounts** | Create in CP/DP namespaces | Namespace-scoped |
| **Secrets** | Create, read, update | Namespace-scoped |
| **ConfigMaps** | Create, read, update | Namespace-scoped |
| **Services** | Create, expose, LoadBalancer type | Namespace-scoped |
| **Ingress** | Create, configure | Namespace-scoped |
| **PVCs** | Create, delete | Namespace-scoped |
| **StorageClasses** | Create, list | Cluster-wide |

### Azure RBAC Integration (If Enabled)

If AKS cluster has Azure RBAC enabled for Kubernetes authorization:
- [ ] Azure AD integration configured
- [ ] User/Service Principal has **Azure Kubernetes Service RBAC Cluster Admin** role
- [ ] Or **Azure Kubernetes Service Cluster Admin** role (non-RBAC)

### Managed Identity Considerations

For AKS cluster with managed identity:
- [ ] System-assigned or user-assigned managed identity enabled
- [ ] Managed identity has required permissions on Azure resources:
  - **Storage Account Contributor** (for Azure Files/Disk)
  - **DNS Zone Contributor** (for External DNS)
  - **Network Contributor** (for Load Balancer)

---

## 11. Resource Quotas and Limits

### Ensure No Restrictive Quotas

Verify that the following quotas are NOT in place (or have sufficient headroom):

| Resource | Control Plane Namespace | Data Plane Namespace (per DP) |
|----------|------------------------|-------------------------------|
| **CPU Requests** | 20+ cores | 10+ cores |
| **Memory Requests** | 40+ GB | 20+ GB |
| **Persistent Volume Claims** | 5+ | 3+ |
| **Services** | 50+ | 30+ |
| **ConfigMaps** | 100+ | 50+ |
| **Secrets** | 100+ | 50+ |
| **LoadBalancer Services** | 2+ | 2+ |

```bash
# Check for resource quotas in target namespaces
kubectl get resourcequota -n <namespace>

# If quotas exist, ensure they allow TIBCO Platform requirements
```

### Azure Subscription Quotas

Verify Azure subscription has sufficient quotas:
- [ ] vCPU quota in target region (minimum 32 vCPUs for CP cluster)
- [ ] Public IP addresses (2+ for Load Balancers)
- [ ] Load Balancers (2+ for ingress)
- [ ] Azure Disk volumes (10+)
- [ ] Azure Files shares (5+)

Check quotas:
```bash
az vm list-usage --location <region> --output table
```

---

## 12. Network Policies

### Ensure Network Policies Allow Required Traffic

If network policies are enforced (Calico):

- [ ] Control Plane pods can communicate with PostgreSQL (port 5432)
- [ ] Control Plane pods can reach container registry (port 443)
- [ ] Data Plane pods can reach Control Plane ingress (`my` and `tunnel` domains, port 443)
- [ ] Ingress controller can route to Control Plane and Data Plane services
- [ ] DNS resolution works from all pods (port 53 to kube-dns/coredns)
- [ ] Azure Storage endpoints accessible (ports 443, 445)

### Default AKS Network Policy

AKS with Calico network policy requires explicit allow rules:
```yaml
# Example: Allow ingress to Control Plane namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-ingress
  namespace: cp1-ns
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: ingress-system
```

---

## 13. Naming Conventions and Instance Identification

### Control Plane Instance ID

| Parameter | Constraint | Example |
|-----------|-----------|---------|
| **Format** | Alphanumeric or underscores only | `cp1`, `nxpcp`, `nxp_tibco_cp` |
| **Max Length** | 5 characters (recommended) | `cp1`, `prod1` |
| **Restrictions** | **NO HYPHENS (-)** | ❌ `nxp-cp`, ❌ `my-control-plane` |
| **Purpose** | Database prefix, namespace naming | Creates `cp1_tscidmdb`, `cp1-ns` |

**⚠️ Critical**: Hyphens cause PostgreSQL database creation failures!

### Namespace Naming

| Component | Namespace Pattern | Example |
|-----------|------------------|---------|
| **Control Plane** | `{instanceId}-ns` | `cp1-ns` |
| **Third-party services** | `tibco-ext` | `tibco-ext` (for PostgreSQL, etc.) |
| **Data Plane** | `{dataplaneId}-ns` | `dp1-ns` |
| **Ingress System** | `ingress-system` | `ingress-system` |
| **Storage System** | `storage-system` | `storage-system` |

---

## 14. Email Server Configuration (Optional but Recommended)

For Control Plane notification emails (user invitations, password resets, etc.):

### Azure-Specific Options

#### Option 1: Azure Communication Services Email (Recommended)

| Parameter | Details |
|-----------|---------|
| **Service** | Azure Communication Services |
| **SMTP Endpoint** | Provided by Azure Communication Services |
| **Authentication** | Azure AD or Connection String |
| **TLS** | Required (port 587) |

#### Option 2: SendGrid on Azure

| Parameter | Details |
|-----------|---------|
| **SMTP Server** | smtp.sendgrid.net |
| **SMTP Port** | 587 (TLS) or 465 (SSL) |
| **Authentication** | API Key |

#### Option 3: Custom SMTP Server

| Parameter | Details |
|-----------|---------|
| **SMTP Server** | Hostname/IP of SMTP server |
| **SMTP Port** | Typically 587 (STARTTLS) or 465 (SSL) or 25 |
| **Authentication** | Username and password (if required) |
| **From Address** | Email address for outgoing notifications |
| **TLS/SSL** | Enabled/Disabled |

**Alternative**: TIBCO can deploy a development mail server (MailDev) for testing purposes.

---

## 15. Browser Requirements (Control Plane UI Access)

### Supported Browsers

For accessing TIBCO Control Plane UI, current versions of the following browsers are supported:

| Browser | Version | Notes |
|---------|---------|-------|
| **Google Chrome** | Current version | Recommended |
| **Mozilla Firefox** | Current version | Fully supported |
| **Microsoft Edge** | Current version (Chromium-based) | Supported |

> **Important**: Always use the latest stable version of supported browsers for optimal performance and security.

---

## 16. Ingress Controller

### Supported Ingress Controllers for AKS

TIBCO Platform supports the following ingress controllers on AKS:

#### Control Plane Ingress Controllers

| Ingress Controller | Version | Notes |
|-------------------|---------|-------|
| **Traefik** | 3.3.4 | **Recommended** - Modern, cloud-native ingress controller |
| **NGINX** | 4.12.1 | ⚠️ **Deprecated from v1.10.0** - Active development ending per NGINX community |

#### Data Plane Ingress Controllers

| Ingress Controller | Version | Use Case |
|-------------------|---------|----------|
| **Traefik** | 3.3.4 | **Recommended** - Data Plane services and apps |
| **NGINX** | 4.12.1 | ⚠️ **Deprecated from v1.10.0** - Legacy support only |
| **Kong** | 2.33.3 | **BusinessWorks Container Edition and Flogo apps only** |

### Control Plane Requirements

| Requirement | Details |
|-------------|---------|
| **Ingress Controller** | Traefik or NGINX must be installed |
| **Ingress Class** | Configured and available (e.g., `traefik`, `nginx`) |
| **TLS Termination** | Ingress controller handles TLS termination |
| **Load Balancer** | Azure Load Balancer with public IP |
| **Service Type** | LoadBalancer (automatic Azure LB provisioning) |
| **Annotations** | Azure-specific annotations for Load Balancer |

#### Traefik Configuration for AKS (Recommended)

```yaml
# Example Traefik values for AKS
service:
  type: LoadBalancer
  annotations:
    service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /ping
ingressClass:
  enabled: true
  name: traefik
  isDefaultClass: true
ports:
  web:
    port: 80
    expose: true
  websecure:
    port: 443
    expose: true
    tls:
      enabled: true
```

#### NGINX Configuration for AKS (Deprecated)

```yaml
# Example NGINX values for AKS (if still using)
controller:
  service:
    type: LoadBalancer
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /healthz
  ingressClassResource:
    name: nginx
    enabled: true
    default: true
```

### Data Plane Requirements

| Requirement | Details |
|-------------|---------|
| **Ingress Controller** | Traefik (recommended), NGINX, or Kong |
| **Ingress Class** | Must match provisioning wizard selection |
| **Kong Ingress** | Only for BusinessWorks Container Edition and Flogo app endpoints |
| **Load Balancer** | Separate Azure Load Balancer for Data Plane (optional) |

> **⚠️ Important**: NGINX ingress controller is **deprecated from TIBCO Control Plane 1.10.0 onwards**. Traefik is the recommended alternative for new deployments.

> **Note**: Kong ingress controller (version 2.33.3) is supported only for BusinessWorks Container Edition and TIBCO Flogo application endpoints.

### Azure Load Balancer Annotations

Key annotations for AKS ingress:
```yaml
annotations:
  service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /health
  service.beta.kubernetes.io/azure-load-balancer-internal: "false"  # Public LB
  service.beta.kubernetes.io/azure-dns-label-name: "tibco-cp"  # DNS label
```

---

## Pre-Installation Checklist

Please complete this checklist and return to TIBCO implementation team **at least 2 business days** before installation date.

### Azure Infrastructure Readiness

- [ ] AKS cluster is running and accessible (Kubernetes 1.32+)
- [ ] `kubectl` CLI access with admin permissions verified
- [ ] `az` CLI installed and configured with correct subscription
- [ ] Helm 3.17.0+ installed on installation machine
- [ ] Cluster has sufficient node resources (CPU, memory)
- [ ] Storage classes for Azure Disk and Azure Files are available
- [ ] No restrictive resource quotas in target namespaces
- [ ] Azure subscription quotas verified (vCPU, IPs, disks)

### Network and Connectivity

- [ ] Internet access from AKS cluster verified (can pull images)
- [ ] Azure DNS zones are available and accessible
- [ ] DNS record creation process is understood and ready
- [ ] DNS resolution working for CP domains from DP cluster (REQUIRED for CP-DP communication)
- [ ] Azure Load Balancer provisioning tested
- [ ] Required network ports are open (NSGs configured)
- [ ] Network policies allow required traffic flows (if Calico enabled)
- [ ] VNet peering configured (OPTIONAL - only if not using DNS for CP-DP communication)

### Storage

- [ ] Azure Storage Account created and configured
- [ ] Storage account name and resource group documented
- [ ] Storage account access key available
- [ ] Azure Disk storage class tested (`azure-disk-sc`)
- [ ] Azure Files storage class tested (`azure-files-sc`)
- [ ] Private endpoints configured for storage (if required)

### Database (Control Plane Only)

- [ ] Azure Database for PostgreSQL Flexible Server created (or in-cluster option confirmed)
- [ ] PostgreSQL 16 version confirmed
- [ ] Database endpoint, port, and credentials documented
- [ ] Master user has database creation privileges verified
- [ ] Database is accessible from AKS pods (firewall/VNet rules)
- [ ] `uuid-ossp` extension available
- [ ] SSL certificate downloaded (BaltimoreCyberTrustRoot.crt.pem)
- [ ] Control Plane instance ID chosen (no hyphens!) and documented

### Security and Certificates

- [ ] SSL/TLS certificates obtained for Control Plane domains
- [ ] Certificate files in PEM format ready
- [ ] Private keys securely stored (Azure Key Vault recommended)
- [ ] Container registry credentials received from TIBCO
- [ ] Container registry access tested and verified

### Secrets Preparation

- [ ] Container registry credentials (URL, username, password) ready
- [ ] Database credentials documented
- [ ] TLS certificate and key files prepared for ingress
- [ ] Azure PostgreSQL SSL certificate downloaded
- [ ] SMTP credentials ready (or MailDev for testing)
- [ ] OpenSSL installed on installation machine (for generating keys)

### Access and Permissions

- [ ] Azure subscription Owner or Contributor access confirmed
- [ ] AKS cluster admin access (Azure RBAC or K8s RBAC)
- [ ] Azure DNS Zone Contributor access confirmed
- [ ] Database admin access confirmed
- [ ] Certificate authority access (or Azure Key Vault access)
- [ ] Managed Identity permissions configured (if using)

### Ingress Controller

- [ ] Ingress controller decided: Traefik (recommended) or NGINX (deprecated)
- [ ] Ingress controller version documented
- [ ] Load Balancer configuration tested
- [ ] Health probe paths configured
- [ ] Azure DNS label configured (optional)

### Documentation and Planning

- [ ] Control Plane instance ID decided: `_______________` (no hyphens!)
- [ ] Control Plane namespace name: `_______________`
- [ ] Data Plane namespace name(s): `_______________`
- [ ] Azure Resource Group: `_______________`
- [ ] DNS domains documented: 
  - Control Plane UI: `_______________`
  - Hybrid Connectivity: `_______________`
- [ ] Azure region: `_______________`
- [ ] Installation timezone and schedule confirmed
- [ ] Escalation contacts identified (for access/permissions issues)

### Optional but Recommended

- [ ] Azure Communication Services or SendGrid configured (for email)
- [ ] Backup strategy planned for PostgreSQL database (Azure automated backups)
- [ ] Azure Monitor configured (for platform metrics and logs)
- [ ] Log Analytics workspace created (for centralized logging)
- [ ] External DNS operator installed (for automated DNS management)
- [ ] Cert-manager installed (for automated certificate management)

---

## Completion Confirmation

**Customer Name**: _______________________________________________

**Project Name**: _______________________________________________

**Azure Subscription ID**: _______________________________________________

**Prepared By**: _______________________________________________

**Date Completed**: _______________________________________________

**Signature**: _______________________________________________

---

## Questions or Issues?

If you encounter any challenges completing these prerequisites, please contact:

**TIBCO Implementation Team**
- Email: _______________________
- Phone: _______________________
- Teams/Slack: _______________________

---

## Appendix: Quick Reference

### Minimum AKS Resource Summary

**Control Plane AKS Cluster:**
- Kubernetes version: 1.32+
- 3+ worker nodes (Standard_D8s_v3 or higher)
- 24+ CPU cores total
- 96+ GB RAM total
- Azure Disk storage (Premium_LRS)
- Azure Files storage (Premium_LRS or Standard_LRS)
- Azure Database for PostgreSQL Flexible Server (16)
- Azure DNS zone for domain management
- Azure Load Balancer (automatic)

**Data Plane AKS Cluster:**
- Kubernetes version: 1.32+
- 2+ worker nodes (Standard_D4s_v3 or higher)
- 8+ CPU cores total
- 32+ GB RAM total
- Azure Files storage
- Network access to Control Plane
- Azure Load Balancer (automatic)

**Control Tower Data Plane (Bare Metal/Single-Cluster):**
- Host OS: Linux (x86_64 architecture)
- 4-core CPU processor
- 8 GB RAM
- 20 GB disk space
- Ingress Controller: Traefik or NGINX
- Storage class for Hawk Console persistence
- Observability: Prometheus (metrics), ElasticSearch (traces)

### Critical "No-Hyphens" Reminder

The following identifiers **MUST NOT contain hyphens**:
- `controlPlaneInstanceId` / `CP_INSTANCE_ID`
- Any identifier used in database naming

**Valid**: `cp1`, `nxpcp`, `nxp_tibco_cp`, `prod1`  
**Invalid**: `nxp-tibco-cp`, `my-cp-instance`, `azure-cp`

### Azure-Specific Naming Constraints

**Storage Account Names**:
- 3-24 characters
- Lowercase letters and numbers only
- Must be globally unique across all Azure

**Resource Group Names**:
- 1-90 characters
- Alphanumeric, underscore, parentheses, hyphen, period (except at end)
- Cannot end with period

**AKS Cluster Names**:
- 1-63 characters
- Alphanumeric, hyphen (except at start/end)
- Must start and end with alphanumeric

---

**Document Version**: 1.0 for AKS  
**Last Updated**: January 22, 2026  
**Next Review**: Before each customer engagement

