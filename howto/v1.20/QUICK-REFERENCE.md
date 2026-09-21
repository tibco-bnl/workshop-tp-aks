# TIBCO Platform v1.20.0 Quick Reference Guide

**TIBCO Platform Version**: 1.20.0 | **Status**: Current release

## Essential Commands

```bash
helm repo add tibco-platform https://tibcosoftware.github.io/tp-helm-charts
helm repo update tibco-platform

kubectl get pods -n cp1-ns
helm list -n cp1-ns
helm history platform-base -n cp1-ns          # keep for rollback
kubectl get ingress -A
kubectl get gatewayclass,gateway,httproute -A
```

## Helm Charts

| Component | Version |
|-----------|---------|
| `tibco-cp-base` | `1.20.0` |
| `tibco-cp-bw` | `1.20.0` |
| `tibco-cp-flogo` | `1.20.0` |
| `tibco-cp-devhub` | `1.20.0` |
| `tibco-cp-hawk` | `1.20.8` |
| `tibco-cp-messaging` | `1.19.23` (no 1.20 release) |
| `tibco-developer-hub` | `1.20.8` |
| `tp-cp-proxy` | `1.20.2` |
| `tp-dp-monitor-agent` | `1.20.2` |
| `o11yservice` | `1.20.5` |
| `jaeger` | `4.8.3` |
| `dp-configure-namespace` | `1.20.0` |
| `dp-core-infrastructure` | `1.20.3` |

## New or Changed in v1.20.0

### Values File Checks

```bash
# Removed in 1.19.0 - must be absent
grep -n "createDeprecatedPolicies" cp-values.yaml && echo "REMOVE this key"
# Chart default is false in 1.20.0 - set explicitly
yq '.["otel-collector"].enabled' cp-values.yaml
# New in 1.20.0 (chart default [MFTADAPTER])
yq '.global.tibco.disabledInfraCapabilities' cp-values.yaml
```

### Control Plane Rollback

```bash
helm history platform-base -n cp1-ns
helm rollback platform-base <revision> -n cp1-ns --wait      # manageDbSchema: true
# manageDbSchema: false -> postgres-helper.bash rollbackDbSchema <chart-version> first
```

### Gateway API Checks (hybrid-proxy route fixed since 1.19.0)

```bash
kubectl get gatewayclass
kubectl get httproute -n cp1-ns hybrid-proxy \
  -o jsonpath='{.spec.hostnames}{"  "}{.spec.rules[*].matches[*].path.value}{"\n"}'
# simplified DNS expected: ["*.<base-domain>"]  /infra/tunnel
```

### Namespace-Level RBAC and MCP RBAC

```bash
kubectl get ns
kubectl get rolebinding,clusterrolebinding -A | grep -i tibco
kubectl get role,clusterrole -A | grep -i "infra-mcp\|mcp-gateway"
```

### Email Server Configuration

Configured in the Platform Console (since 1.18.0). MailDev: host `development-mailserver.tibco-ext.svc.cluster.local`, port `1025`, TLS disabled.

## Upgrade Order (from 1.19.0)

1. Back up Helm values, secrets, and database state; record `helm history`.
2. Upgrade `tibco-cp-base` to 1.20.0 (`scripts/1.20.0/upgrade.sh` or `helm upgrade --version 1.20.0`).
3. Upgrade BW, Flogo, Developer Hub to 1.20.0 and Hawk to `1.20.*`.
4. Upgrade Data Plane infrastructure from the Control Plane UI, then capabilities.
5. Re-check Gateway API endpoints, namespace RBAC, and observability cards.
6. Validate with `scripts/verify-release.sh` (`CHECK_RELEASE_FOLDER=control-plane`, `CHECK_RELEASE_VERSION=1.20.0`).

From 1.18.0, upgrade to 1.19.0 first: [1.19.0 quick reference](../v1.19/QUICK-REFERENCE).

## Known Issues Quick Check

- PCP-23615: Data Plane observability configuration cannot be deleted after the 1.20.0 upgrade.
- PLTDX-1343: use Azure Disk, not `azure-files-sc`, for the Developer Hub PostgreSQL pod.
- PLTDX-1459: distinct FQDNs for CP and Developer Hub behind Traefik.
- FLOGO-18866: use `wss://` for WebSocket public endpoints.

## Official References

- [TIBCO Platform 1.20.0 Documentation](https://docs.tibco.com/pub/platform-cp/1.20.0/doc/html/Default.htm)
- [Official 1.20.0 New Features](https://docs.tibco.com/pub/platform-cp/1.20.0/doc/html/Release-Notes/new-features.htm)
- [Official 1.20.0 Known Issues](https://docs.tibco.com/pub/platform-cp/1.20.0/doc/html/Release-Notes/known-issues.htm)
- [Control Plane Rollback](https://docs.tibco.com/pub/platform-cp/1.20.0/doc/html/UserGuide/control-plane-rollback.htm)
- [TIBCO tp-helm-charts](https://github.com/TIBCOSoftware/tp-helm-charts)
