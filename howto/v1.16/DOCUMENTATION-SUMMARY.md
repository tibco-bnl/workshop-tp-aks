# TIBCO Platform v1.16.0 Documentation Summary

**Date**: April 10, 2026  
**Cluster**: dp1-aks-aauk-kul  
**Namespace**: cp1-ns  
**Status**: ✅ Successfully Documented from Running Environment

---

## What Was Captured

This document summarizes what was captured from the running TIBCO Platform Control Plane v1.16.0 installation on the dp1-aks-aauk-kul cluster and how the documentation was updated.

---

## 1. Environment Details Captured

### From Running Cluster (dp1-aks-aauk-kul, namespace: cp1-ns)

#### Helm Releases
```
NAME                            CHART                           VERSION
tibco-cp-base                   tibco-cp-base                   1.16.0
tibco-cp-bw                     tibco-cp-bw                     1.16.0
tibco-cp-flogo                  tibco-cp-flogo                  1.16.0
tibco-cp-devhub                 tibco-cp-devhub                 1.16.0
tibco-cp-hawk                   tibco-cp-hawk                   1.16.6
tibco-cp-messaging              tibco-cp-messaging              1.15.31
sub-*                           tp-cp-subscription              1.16.0
dp-*                            tp-cp-data-plane                1.15.0
```

#### Configuration Values Extracted
- ✅ Control Plane base configuration (helm values)
- ✅ BW capability configuration
- ✅ Flogo capability configuration
- ✅ Developer Hub configuration
- ✅ Hawk monitoring configuration
- ✅ Messaging configuration
- ✅ Container registry details (v1.16.0 registry)
- ✅ Database configuration
- ✅ Ingress routing (Traefik)
- ✅ DNS domains (including new AI endpoint)
- ✅ Storage configuration (Azure Files)
- ✅ Observability integration (Elasticsearch, Prometheus)

#### Infrastructure Details
- **Ingress Controller**: Traefik (ingressClassName: traefik)
- **LoadBalancer IP**: 40.114.164.16
- **Storage Class**: azure-files-sc (Control Plane PVC)
- **Database**: PostgreSQL (postgresql.tibco-ext.svc.cluster.local)
- **Logging**: Elasticsearch (elastic-system namespace)
- **Email**: MailDev (tibco-ext namespace)

#### DNS Configuration
- **Admin**: admin.dp1.atsnl-emea.azure.dataplanes.pro
- **AI Services**: ai.dp1.atsnl-emea.azure.dataplanes.pro (NEW in v1.16.0)
- **Wildcard**: *.dp1.atsnl-emea.azure.dataplanes.pro

---

## 2. Files Created

### Directory Structure Created
```
scripts/v1.16.0-cpdp-install/
├── README.md                          # Installation guide
├── aks-env-variables-dp1.sh           # Environment variables
└── values/
    ├── cp1-values.yaml                # Control Plane values
    ├── postgresql-values.yaml         # PostgreSQL values
    └── maildev-deployment.yaml        # MailDev SMTP server

howto/v1.16/
└── (ready for additional guides)

releases/
└── v1.16.0.md                         # Release notes
```

### Files Created/Updated

#### 1. Environment Variables
**File**: `scripts/v1.16.0-cpdp-install/aks-env-variables-dp1.sh`
- Updated from v1.15.0 configuration
- Changed container registry to: `csgprdusw2reposaas.jfrog.io`
- Added AI domain: `CP_AI_DNS_DOMAIN=ai.dp1.atsnl-emea.azure.dataplanes.pro`
- Updated LoadBalancer IP: `40.114.164.16`
- Removed tunnel domain (replaced with AI domain)
- Updated version variables to 1.16.0

#### 2. Control Plane Values
**File**: `scripts/v1.16.0-cpdp-install/values/cp1-values.yaml`
- Based on actual running helm values from `helm get values tibco-cp-base -n cp1-ns`
- Key configurations:
  - `useSingleNamespace: true` (REQUIRED for v1.16.0)
  - `hybridConnectivity.enabled: true` (AI services)
  - `bwmcpserver.enabled: true` (Model Context Protocol for BW)
  - `mcpserver.enabled: true` (Model Context Protocol for Flogo)
  - Ingress routes for both `admin` and `ai` subdomains
  - Elasticsearch integration for logging and audit
  - MailDev SMTP server configuration

#### 3. PostgreSQL Values
**File**: `scripts/v1.16.0-cpdp-install/values/postgresql-values.yaml`
- Updated container registry to v1.16.0 registry
- Maintained PostgreSQL 16.4.0 configuration
- Azure Disk storage (managed-csi-premium)

#### 4. MailDev Deployment
**File**: `scripts/v1.16.0-cpdp-install/values/maildev-deployment.yaml`
- SMTP server for development/testing
- Ingress route: mail.dp1.atsnl-emea.azure.dataplanes.pro
- No changes from v1.15.0 (still compatible)

#### 5. Release Notes
**File**: `releases/v1.16.0.md`
- Comprehensive release notes for v1.16.0
- Component versions and chart versions
- DNS architecture changes
- Configuration highlights
- Verified features
- Known issues and workarounds
- Upgrade path from v1.15.0

#### 6. Installation Guide
**File**: `scripts/v1.16.0-cpdp-install/README.md`
- Complete installation instructions
- Environment setup
- Helm installation commands
- Troubleshooting section
- Configuration reference

#### 7. Main Setup Guide Updated
**File**: `howto/how-to-cp-and-dp-aks-setup-guide.md`
- Updated references from v1.15.0 to v1.16.0
- Changed environment file path to v1.16.0 directory
- Updated DNS configuration examples
- Added AI domain configuration

---

## 3. Key Changes from v1.15.0 to v1.16.0

### Container Registry Changes
| Aspect | v1.15.0 | v1.16.0 |
|--------|---------|---------|
| Registry URL | csgprdeuwrepoedge.jfrog.io | csgprdusw2reposaas.jfrog.io |
| Repository | tibco-platform-docker-prod | tibco-platform-docker-dev |
| Credentials | Updated | New credentials required |

### DNS Architecture Changes
| Domain Type | v1.15.0 | v1.16.0 |
|-------------|---------|---------|
| Admin Console | admin.{base-domain} | admin.{base-domain} *(same)* |
| Tunnel/AI | tunnel.{base-domain} | ai.{base-domain} *(renamed & enhanced)* |
| Data Plane Apps | *.{base-domain} | *.{base-domain} *(same)* |

### New Features in v1.16.0
- ✅ **License Management**: View details and expiration notifications (90/30/7 days)
- ✅ **BW6 AI Plugin 6.0.0**: RAG capabilities for AI-powered applications (Preview)
- ✅ **BW5 Enhancements**: Historical logs, audit history, metrics charts
- ✅ **BW5 Containers**: Custom base image and CyberArk Conjur support
- ✅ **Flogo Enhancements**: Init/sidecar containers, API version control
- ✅ **Developer Hub**: Update URL through UI with ingress flexibility
- ✅ **Hybrid Connectivity**: Improved cloud-edge integration

### Configuration Changes
- ✅ **Hybrid Connectivity**: Now enabled by default (`hybridConnectivity.enabled: true`)
- ✅ **MCP Servers**: Enabled for BW and Flogo (`bwmcpserver.enabled`, `mcpserver.enabled`)
- ✅ **Single Namespace**: Explicitly required (`useSingleNamespace: true`)
- ✅ **Ingress Routes**: Updated to include AI subdomain

---

## 4. What Was NOT Changed

### No Changes Made to Running Environment
- ❌ No pods restarted
- ❌ No configurations modified
- ❌ No helm releases upgraded
- ❌ No secrets changed
- ❌ No ingress routes modified

**Approach**: Read-only operations only - captured configuration from running environment without making any changes.

### Files Not Modified
- ✅ v1.15.0 files kept intact (in `scripts/v1.15.0-cpdp-install/`)
- ✅ Generic templates unchanged (`scripts/aks-env-variables.sh`)
- ✅ v1.14.0 documentation preserved
- ✅ Architecture diagrams not updated yet

---

## 5. Verification Steps Performed

### Cluster Access
```bash
✅ kubectl config current-context  # Verified: dp1-aks-aauk-kul
✅ helm list -n cp1-ns             # Listed all releases
✅ kubectl get pods -n cp1-ns      # Verified all pods running
✅ kubectl get ingress -n cp1-ns   # Captured ingress configuration
✅ kubectl get pvc -n cp1-ns       # Captured storage configuration
```

### Configuration Extraction
```bash
✅ helm get values tibco-cp-base -n cp1-ns
✅ helm get values tibco-cp-bw -n cp1-ns
✅ helm get values tibco-cp-flogo -n cp1-ns
✅ helm get values tibco-cp-devhub -n cp1-ns
✅ helm get values tibco-cp-hawk -n cp1-ns
✅ helm get values tibco-cp-messaging -n cp1-ns
```

---

## 6. How to Use This Documentation

### For New Installations
1. **Use v1.16.0 Configuration**: Start with `scripts/v1.16.0-cpdp-install/`
2. **Follow Installation Guide**: `scripts/v1.16.0-cpdp-install/README.md`
3. **Reference Release Notes**: `releases/v1.16.0.md`
4. **Check Main Guide**: `howto/how-to-cp-and-dp-aks-setup-guide.md` (updated)

### For Upgrades from v1.15.0
1. **Review Release Notes**: Check breaking changes in `releases/v1.16.0.md`
2. **Update Environment File**: Modify container registry and AI domain
3. **Update Values Files**: Use v1.16.0 templates as reference
4. **Perform Helm Upgrade**: Follow upgrade instructions (to be created)

### For Recreating This Environment Later
1. **Source Environment Variables**: 
   ```bash
   source scripts/v1.16.0-cpdp-install/aks-env-variables-dp1.sh
   ```
2. **Use Values Files**: Apply helm values from `values/` directory
3. **Follow Installation Order**: Per README.md in v1.16.0 directory
4. **Verify Against Release Notes**: Use verification checklist

---

## 7. Next Steps Recommended

### Documentation Tasks
- [ ] Create detailed upgrade guide: `howto/v1.16/UPGRADE-1.15-TO-1.16.md`
- [ ] Update architecture diagrams with AI services endpoint
- [ ] Create troubleshooting guide specific to v1.16.0
- [ ] Document Data Plane v1.16.0 configuration

### Testing & Validation
- [ ] Test fresh installation using v1.16.0 values files
- [ ] Validate upgrade path from v1.15.0 clean install
- [ ] Document any additional prerequisites discovered
- [ ] Create automated test scripts

### Automation
- [ ] Create installation scripts (`01-install-cp.sh`, etc.)
- [ ] Create upgrade scripts for v1.15.0 → v1.16.0
- [ ] Add verification scripts
- [ ] Create rollback procedures

### Environment Maintenance
- [ ] Consider cleaning up failed v1.15.0 artifacts
- [ ] Document any manual fixes applied
- [ ] Update backup/restore procedures for v1.16.0
- [ ] Document disaster recovery steps

---

## 8. Known Issues & Considerations

### tibco-cp-base "Failed" Status
- **Observation**: Helm shows "failed" status for tibco-cp-base
- **Reality**: All components running successfully
- **Impact**: None - operational system
- **Recommendation**: Monitor during next upgrade operation

### Data Plane Components Still on v1.15.0
- **Observation**: Some data plane helm releases showing 1.15.0
- **Impact**: Compatible with v1.16.0 Control Plane
- **Recommendation**: Plan Data Plane upgrade separately

---

## 9. Contributors & Timeline

| Date | Activity | By |
|------|----------|-----|
| April 9-10, 2026 | v1.16.0 installation completed | Colleague |
| April 10, 2026 | Configuration captured & documented | Documentation Team |
| April 10, 2026 | v1.16.0 documentation created | Documentation Team |
| April 10, 2026 | v1.15.0 references updated | Documentation Team |

---

## 10. References

### Internal Documentation
- [v1.16.0 Release Notes](/releases/v1.16.0.md)
- [v1.16.0 Installation Guide](/scripts/v1.16.0-cpdp-install/README.md)
- [Main Setup Guide](/howto/how-to-cp-and-dp-aks-setup-guide.md)
- [v1.15.0 Release Notes](/releases/v1.15.0.md) (for comparison)

### External Resources
- [TIBCO Platform Helm Charts](https://github.com/TIBCOSoftware/tp-helm-charts)
- [TIBCO Platform Documentation](https://docs.tibco.com/)

---

**Document Status**: Complete ✅  
**Last Updated**: April 10, 2026  
**Next Review**: Upon next platform upgrade
