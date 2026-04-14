# TIBCO Platform v1.16.0 - Accurate Feature Summary

**Updated**: April 10, 2026  
**Based on**: [Official TIBCO Documentation](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#Release-Notes/new-features.htm) and [GitHub tp-helm-charts releases](https://github.com/TIBCOSoftware/tp-helm-charts/releases)

---

## ✅ What's Actually New in v1.16.0

### TIBCO Control Plane

#### License Management Enhancements
- **License Details View**: After uploading a license file, view details including:
  - File name
  - Customer name
  - Expiration date
  - Product list
- **Expiration Notifications**: Receive UI notifications when licenses expire within:
  - 90 days
  - 30 days
  - 7 days

### BusinessWorks 6 (Containers)

#### AI Plugin 6.0.0 (Preview)
- **RAG Palette**: Retrieval-Augmented Generation capabilities
- **Features**:
  - Chunking large datasets
  - Inserting processed data into vector databases
  - Retrieving relevant information for context-aware AI responses
  - Grounded in private datasets
- **Status**: Preview mode

### BusinessWorks 5 and ActiveMatrix Adapters

#### Enhanced Monitoring and Auditing
- **Historical Logs**: Integrated access for root-cause analysis
- **Audit History**: Streamlined system auditing
- **Metrics View**: Interactive time-series charts showing:
  - CPU utilization
  - Memory utilization
  - Successful execution details
  - Failed execution details
- **Domain Display Cards**: Clear permission indicators showing 'Read' or 'Write' access levels
- **License Warnings**: Banner on "All Applications" page when product license expires within 90 days

> **Note**: Historical Logs and Audit History NOT applicable for adapters

### BusinessWorks 5 (Containers)

- **Custom Base Image**: Functionality for using custom base images
- **CyberArk Conjur**: Credential management for password fields in:
  - OOTB palette activities
  - Shared resources at run-time

### Flogo Capability

#### Deployment Enhancements
- **Init Containers**: Include `initContainer` sections in `values.yaml` for Helm deployments
- **Sidecar Containers**: Include `sidecar` container sections in `values.yaml`

#### CLI Improvements
- **`--all` Flag**: Added to commands:
  - `tibcop flogo:list-connectors --all`: List all connectors including non-provisioned
  - `tibcop flogo:list-flogo-versions --all`: List all Flogo versions including non-provisioned

#### API Enhancements
- **Version Selection**: `POST /v1/dp/builds` API enhanced to specify versions for:
  - Connectors
  - Custom extensions
- **Benefits**: Control over dependencies, use desired versions

#### Resource Customization
- **Flogo Provisioner Resources**: Customize resource requests and limits in helm chart
- **Override Method**: Specify values in parent Helm chart's `values.yaml`

### Developer Hub

#### URL Management
- **Update Developer URL**: Modify through UI
- **Ingress Controller Flexibility**:
  - Add new ingress controllers (e.g., HAProxy)
  - Use existing ingress controllers
- **Secret Management**: Update Kubernetes secret objects associated with Developer URL

---

## 🔍 Important Clarifications

### The "AI" Domain Misconception

**What we observed on the cluster:**
- Domain: `ai.dp1.atsnl-emea.azure.dataplanes.pro`
- Ingress route in router-operator and hybrid-proxy

**What it actually is:**
```yaml
# From helm get values sub-d7bs1l819a2c73fg2ujg -n cp1-ns
hostPrefix: ai
subscriptionId: d7bs1l819a2c73fg2ujg
```

**Clarification:**
- This is a **Control Plane subscription** with `hostPrefix: ai`
- NOT a new "AI Services" platform feature in v1.16.0
- The actual AI feature is the **BW6 AI Plugin 6.0.0** with RAG capabilities

### Container Registry Changes

| Aspect | v1.15.0 | v1.16.0 |
|--------|---------|---------|
| Registry URL | csgprdeuwrepoedge.jfrog.io | csgprdusw2reposaas.jfrog.io |
| Repository | tibco-platform-docker-prod | tibco-platform-docker-dev |
| Impact | Breaking change | Update values files |

### Component Versions

| Component | Chart Version | App Version |
|-----------|---------------|-------------|
| Control Plane Base | 1.16.0 | 1.16.0 |
| BW | 1.16.0 | 1.16.0 |
| Flogo | 1.16.0 | 1.16.0 |
| Developer Hub | 1.16.0 | 1.16.0 |
| Hawk | 1.16.6 | 1.16.0 |
| Messaging | 1.15.31 | 1.15.0-30 |
| Event Processing | 1.16.0 | - |

---

## 📚 References

### Official Documentation
- [TIBCO Platform 1.16.0 New Features](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Default.htm#Release-Notes/new-features.htm)
- [TIBCO Platform Control Plane Documentation](https://docs.tibco.com/pub/platform-cp/latest/doc/html/)

### GitHub Repositories
- [tp-helm-charts releases](https://github.com/TIBCOSoftware/tp-helm-charts/releases)
- [tp-helm-charts repository](https://github.com/TIBCOSoftware/tp-helm-charts)

### Specific Component Documentation
- [Flogo: Deploying with Helm Charts](https://docs.tibco.com/pub/platform-cp/1.16.0/doc/html/Subsystems/flogo-capability/flogo-user-guide/deploying-app-build-helm-charts.htm)
- [Flogo: CLI Commands Reference](https://docs.tibco.com/pub/platform-cp/latest/doc/html/CLI/flogo-cli-commands-reference.htm)
- [Flogo: Application and Build Management APIs](https://docs.tibco.com/pub/platform-cp/1.16.0/doc/html/Subsystems/flogo-capability/flogo-user-guide/api-apps-and-builds.htm)
- [Activation Configuration](https://docs.tibco.com/pub/platform-cp/latest/doc/html/UserGuide/configuring-activation-server-url.htm)
- [Installing tibco-cp-flogo chart](https://docs.tibco.com/pub/platform-cp/latest/doc/html/Installation/installing-flogo-chart.htm)

---

## ✅ Corrected Documentation Files

The following files have been updated to reflect accurate v1.16.0 features:

1. ✅ `releases/v1.16.0.md` - Release notes corrected
2. ✅ `README.md` - Version summary updated
3. ✅ `scripts/v1.16.0-cpdp-install/aks-env-variables-dp1.sh` - Comments clarified
4. ✅ `scripts/v1.16.0-cpdp-install/values/cp1-values.yaml` - Comments updated
5. ✅ `howto/v1.16/QUICK-REFERENCE.md` - Features corrected
6. ✅ `howto/v1.16/DOCUMENTATION-SUMMARY.md` - Features updated

---

## 🎯 Key Takeaways

### For Documentation Users
1. **The "ai" subdomain is a subscription**, not a platform AI feature
2. **BW6 AI Plugin 6.0.0** is the actual AI-related enhancement (RAG capabilities)
3. Focus on **license management**, **monitoring enhancements**, and **deployment flexibility** as key v1.16.0 improvements

### For Administrators
1. Update container registry credentials when upgrading
2. Explore license management features for better visibility
3. Consider BW6 AI Plugin for RAG-powered applications (Preview)
4. Leverage Flogo init/sidecar container support for complex deployments

### For Developers
1. BW6: Explore AI Plugin 6.0.0 RAG capabilities
2. BW5: Utilize new monitoring and audit features
3. Flogo: Use init/sidecar containers and version-specific API builds
4. All: Update to latest CLI tools for new flags and features

---

**Last Updated**: April 10, 2026  
**Status**: Corrected based on official TIBCO documentation  
**Next Review**: When v1.17.0 is released
