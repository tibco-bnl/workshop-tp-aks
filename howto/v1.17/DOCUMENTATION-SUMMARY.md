# TIBCO Platform v1.17.0 Documentation Summary

**Date**: May 18, 2026  
**Status**: ✅ Documentation Updated

---

## What Was Updated

This document summarizes the documentation updates made for TIBCO Platform v1.17.0 in the workshop-tp-aks repository.

---

## 1. Files Created/Updated

### New Files
```
howto/v1.17/
├── QUICK-REFERENCE.md         # Quick commands and v1.17 snippets for AKS
└── DOCUMENTATION-SUMMARY.md  # This file

releases/
└── v1.17.0.md                 # Full release notes for v1.17.0
```

### Modified Files
- **README.md** — v1.17.0 listed as a previous release with version-specific setup, quick reference, and release notes

---

## 2. Key Changes from v1.16.0 to v1.17.0

### New Features Overview

#### 1. Webhook Receiver for Alerts
- **What**: HTTP webhook integration for alert notifications
- **Format**: Standardized JSON payload to any external endpoint
- **Use Cases**: PagerDuty, ServiceNow, Slack, Teams, custom notification systems
- **AKS Impact**: Ensure egress NetworkPolicy allows outbound to webhook endpoints from `cp1-ns`

#### 2. OpenSearch Support for Observability
- **What**: OpenSearch can now be used as the backend for Jaeger traces and service logs
- **Alternative to**: Elasticsearch (ECK) — existing ECK deployments continue to work
- **AKS Impact**: OpenSearch Operator available for Kubernetes; deploy in `elastic-system` or dedicated namespace
- **Index Templates**: Required for TIBCO Platform workloads — apply before connecting

#### 3. Capability Management APIs
- **Update API (PUT)**: Update existing capability instances without re-provisioning
- **Upgrade API**: Upgrade capability instances via REST — enables CI/CD automation

#### 4. BW6 (Containers) — Custom Fluentbit
- **What**: Set customized Fluentbit configurations during BW6 capability provisioning or update
- **Requires**: Capability version 1.17.0+
- **AKS Impact**: No special configuration needed beyond capability Helm values

#### 5. BW6 Classic — Full Lifecycle Management UI
- **What**: Agent, Domain, AppSpace, AppNode, and Application management now in Control Plane UI
- **Scope**: Create, update, delete, start, stop, deploy, undeploy all BW6 classic entities
- **Audit**: Application Command History and Execution History available

#### 6. BW5 — Application History
- **What**: New History tab in Application Configuration shows deploy/undeploy audit trail

#### 7. BW5 (Containers) — Custom Fluentbit + Hawk REST API
- **Fluentbit**: Set customized log pipeline during BW5CE capability provisioning or update
- **Hawk REST API**: New endpoint on port 8090 (`/commands`) exposes 31 Hawk methods via REST
- **AKS Impact**: NetworkPolicy updates may be needed to allow port 8090 for BW5CE pods

#### 8. Flogo — Fluentbit, Recipe Customization, New Connectors
- **Fluentbit**: Configure via Helm chart values (consistent with BW5/BW6 approach)
- **Recipe Editor**: YAML editor in Control Plane UI for capability provisioning/update
- **New Connectors**: Google Cloud Storage, TIBCO ActiveSpaces, TIBCO FTL

---

## 3. Component Versions

| Component | v1.16.0 | v1.17.0 |
|-----------|---------|---------|
| tibco-cp-base | 1.16.0 | **1.17.0** |
| tibco-cp-bw | 1.16.0 | **1.17.0** |
| tibco-cp-flogo | 1.16.0 | **1.17.0** |
| tibco-cp-devhub | 1.16.0 | **1.17.0** |
| tibco-cp-addon-eventprocessing | 1.16.0 | **1.17.0** |
| tp-dp-monitor-agent | 1.16.x | **1.17.13** |
| tp-dp-license-file | 1.16.0 | **1.17.0** |
| tp-cp-proxy | 1.16.x | **1.17.4** |

---

## 4. AKS-Specific Considerations

### Container Registry
- No registry change from v1.16.0 — continue using `csgprdusw2reposaas.jfrog.io`

### Ingress (Traefik)
- No ingress controller changes required for v1.17.0
- Existing Traefik configuration remains compatible

### Storage
- No storage class changes required for v1.17.0
- Existing Azure Files (`azure-files-sc`) and Azure Disk configurations remain valid

### NetworkPolicy Updates (if restrictive)
- **BW5CE port 8090**: Add ingress rule for the new Hawk REST API endpoint
- **Webhook Receiver**: Add egress rule to allow outbound to webhook endpoints from `cp1-ns`

### OpenSearch on AKS
- Use OpenSearch Operator for Kubernetes for a managed deployment
- Or connect to an external OpenSearch cluster (Azure-hosted or self-managed)
- Apply index templates before connecting TIBCO Platform

---

## 5. Upgrade Considerations

### Recommended Upgrade Path
- **v1.16.0 → v1.17.0**: Direct upgrade supported
- **v1.15.0 → v1.17.0**: Not recommended — upgrade v1.15.0 → v1.16.0 first
- **v1.14.0 → v1.17.0**: Multi-step: v1.14.0 → v1.15.0 → v1.16.0 → v1.17.0

### Post-Upgrade Checklist
- [ ] All pods running: `kubectl get pods -n cp1-ns`
- [ ] Helm releases healthy: `helm list -n cp1-ns`
- [ ] Ingress accessible: test admin console URL
- [ ] If using OpenSearch: apply index templates
- [ ] If using Webhook Alerts: configure NSG/NetworkPolicy egress
- [ ] If using BW5CE: verify or update NetworkPolicy for port 8090
