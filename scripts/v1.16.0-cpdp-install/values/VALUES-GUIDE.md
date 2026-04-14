# TIBCO Platform Control Plane Values Files - Guide

**Location**: `/Users/kul/git/tib/workshop-tp-aks/scripts/v1.16.0-cpdp-install/values/`  
**Last Updated**: April 10, 2026

---

## Available Values Files

### 1. `cp1-values.yaml` (Production Ready)

**Purpose**: Ready-to-use values file based on actual running production environment

**Source**: Extracted from running cp1-ns namespace on dp1-aks-aauk-kul cluster

**When to Use**:
- ✅ Quick deployment matching the reference environment
- ✅ Workshop or demo environments
- ✅ As a starting point for your own deployment
- ✅ When you want minimal configuration with sensible defaults

**Key Features**:
- Active configuration from running environment
- Important optional values commented for easy enabling
- Prerequisites clearly documented
- Session keys configuration included
- Network policy examples provided

**Usage**:
```bash
helm install tibco-cp-base tibco-platform/tibco-cp-base \
  --version 1.16.0 \
  -n cp1-ns \
  -f values/cp1-values.yaml
```

---

### 2. `cp1-values-enhanced.yaml` (Complete Reference)

**Purpose**: Comprehensive reference with ALL possible configuration options

**Source**: Combined official chart schema with running environment values

**When to Use**:
- 📚 As a complete reference guide
- 🔧 When you need advanced configurations
- 🏢 For production deployments requiring all options
- 🎓 To learn about all available settings
- ⚙️ When troubleshooting configuration issues

**Key Features**:
- Every possible configuration option from official chart
- Detailed comments explaining each parameter
- Resource limits and requests for all components
- Gateway API configuration examples
- OpenTelemetry collector settings
- Multi-region configuration options
- Advanced network policy configurations

**Usage**:
```bash
# Review and customize based on your needs
vim values/cp1-values-enhanced.yaml

# Then use in installation
helm install tibco-cp-base tibco-platform/tibco-cp-base \
  --version 1.16.0 \
  -n cp1-ns \
  -f values/cp1-values-enhanced.yaml
```

---

## Configuration Comparison

| Aspect | cp1-values.yaml | cp1-values-enhanced.yaml |
|--------|-----------------|--------------------------|
| **Size** | ~300 lines | ~600+ lines |
| **Complexity** | Minimal | Complete |
| **Documentation** | Essential notes | Extensive comments |
| **Optional Values** | Key ones commented | All options commented |
| **Use Case** | Quick deployment | Full customization |
| **Updates** | From running env | From official schema |

---

## Required Prerequisites (Both Files)

Before using either values file, you MUST create these Kubernetes secrets:

### 1. Session Keys (REQUIRED)
```bash
kubectl create secret generic session-keys -n cp1-ns \
  --from-literal=TSC_SESSION_KEY=$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c32) \
  --from-literal=DOMAIN_SESSION_KEY=$(openssl rand -base64 48 | tr -dc 'A-Za-z0-9' | head -c32)
```

### 2. Database Credentials
```bash
kubectl create secret generic cp-db-secret -n cp1-ns \
  --from-literal=username=postgres \
  --from-literal=password=postgres
```

### 3. Container Registry Credentials
```bash
kubectl create secret docker-registry tibco-container-registry-credentials -n cp1-ns \
  --docker-server=csgprdusw2reposaas.jfrog.io \
  --docker-username=tibco-platform-devqa \
  --docker-password=$TP_CONTAINER_REGISTRY_PASSWORD \
  --docker-email=your-email@example.com
```

### 4. Encryption Secret
```bash
kubectl create secret generic cporch-encryption-secret -n cp1-ns \
  --from-literal=CP_ENCRYPTION_SECRET=CP_ENCRYPTION_SECRET
```

---

## Key Configuration Sections

### Global Settings
Both files configure:
- Control Plane instance ID (`cp1`)
- Service account
- Container registry details
- Hybrid connectivity
- Single namespace mode

### Database Configuration
```yaml
external:
  db_host: "postgresql.tibco-ext.svc.cluster.local"
  db_name: "postgres"
  db_port: "5432"
  db_ssl_mode: "disable"
```

### Ingress Configuration
```yaml
router-operator:
  ingress:
    enabled: true
    ingressClassName: "traefik"
    hosts:
      - host: "admin.dp1.atsnl-emea.azure.dataplanes.pro"
      - host: "ai.dp1.atsnl-emea.azure.dataplanes.pro"  # Example subscription
```

### Storage Configuration
```yaml
storage:
  resources:
    requests:
      storage: "10Gi"
  storageClassName: "azure-files-sc"
```

---

## Customization Workflow

### For Quick Deployment (Recommended for most users)

1. **Start with `cp1-values.yaml`**
2. Update these minimal required values:
   ```yaml
   global.tibco.controlPlaneInstanceId: "your-id"
   global.tibco.containerRegistry.password: "your-password"
   global.external.db_host: "your-db-host"
   global.external.dnsDomain: "your-domain"
   router-operator.ingress.hosts: [...]  # Your hostnames
   ```
3. Create required secrets
4. Deploy

### For Advanced Deployment

1. **Start with `cp1-values-enhanced.yaml`**
2. Review all sections
3. Uncomment and configure:
   - Network policies
   - Resource limits
   - Gateway API (if using)
   - OpenTelemetry
   - Advanced database settings
4. Test in non-production first
5. Deploy to production

---

## Important Notes

### Security Considerations
⚠️ **DO NOT commit sensitive values to git**
- Container registry passwords
- Database passwords
- Encryption secrets
- Email server credentials

**Best Practice**: Use external secret management (e.g., Azure Key Vault, Kubernetes External Secrets)

### Resource Planning
The values files use minimal resources suitable for dev/workshop:
- Standard pods: 100m CPU, 128-256Mi RAM
- Hawk: 100m CPU, 512Mi RAM
- Prometheus: 100m CPU, 512Mi RAM

**For Production**:
- Review `cp1-values-enhanced.yaml` resource limits
- Adjust based on workload
- Enable resource constraints
- Set appropriate limits

### Network Policies
Both files have network policies disabled by default.

**For Production**:
- Enable `createNetworkPolicy: true`
- Configure CIDR ranges in `cp1-values-enhanced.yaml`
- Test connectivity before full deployment

---

## Validation Commands

### Before Installation
```bash
# Verify secrets exist
kubectl get secrets -n cp1-ns | grep -E "session-keys|cp-db-secret|tibco-container|cporch-encryption"

# Validate values file syntax
helm template tibco-cp-base tibco-platform/tibco-cp-base \
  --version 1.16.0 \
  -f values/cp1-values.yaml \
  --dry-run > /dev/null
```

### After Installation
```bash
# Check all pods running
kubectl get pods -n cp1-ns

# Verify helm release
helm list -n cp1-ns

# Check ingress routes
kubectl get ingress -n cp1-ns
```

---

## Troubleshooting

### Common Issues

**1. Session Keys Missing**
```
Error: secret "session-keys" not found
```
**Solution**: Create session-keys secret as shown in prerequisites

**2. Container Registry Auth Failed**
```
Error: ImagePullBackOff
```
**Solution**: Verify container registry credentials and secret

**3. Database Connection Failed**
```
Error: could not connect to database
```
**Solution**: Check db_host, credentials, and network connectivity

**4. Ingress Not Working**
```
503 Service Unavailable
```
**Solution**: Verify ingress controller running and DNS configured

---

## Additional Resources

### Official Documentation
- [TIBCO Platform Helm Charts](https://github.com/TIBCOSoftware/tp-helm-charts)
- [tibco-cp-base Chart](https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/charts/tibco-cp-base)
- [Values Schema](https://github.com/TIBCOSoftware/tp-helm-charts/blob/main/charts/tibco-cp-base/values.yaml)

### Local Documentation
- [Installation Guide](../README.md)
- [Setup Guide](/howto/how-to-cp-and-dp-aks-setup-guide.md)
- [Release Notes](/releases/v1.16.0.md)
- [Quick Reference](/howto/v1.16/QUICK-REFERENCE.md)

---

## Version History

| Date | File | Changes |
|------|------|---------|
| 2026-04-10 | cp1-values.yaml | Initial from running environment |
| 2026-04-10 | cp1-values-enhanced.yaml | Complete schema reference added |
| 2026-04-10 | VALUES-GUIDE.md | This guide created |

---

**Questions or Issues?**
- Review [Troubleshooting Guide](/docs/troubleshooting-v1.16.md)
- Check [Known Issues](/releases/v1.16.0.md#known-issues--workarounds)
- Consult TIBCO Platform documentation

---

**Last Updated**: April 10, 2026  
**Chart Version**: 1.16.0  
**Cluster**: dp1-aks-aauk-kul
