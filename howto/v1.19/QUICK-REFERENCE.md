# TIBCO Platform v1.19.0 Quick Reference Guide

**TIBCO Platform Version**: 1.19.0 | **Status**: Previous release (upgrade hop to 1.20.0)

## Essential Commands

```bash
helm repo add tibco-platform https://tibcosoftware.github.io/tp-helm-charts
helm repo update tibco-platform

kubectl get pods -n cp1-ns
helm list -n cp1-ns
kubectl get ingress -A
kubectl get gatewayclass,gateway,httproute -A
```

## Helm Charts

| Component | Version |
|-----------|---------|
| `tibco-cp-base` | `1.19.0` |
| `tibco-cp-bw` | `1.19.0` |
| `tibco-cp-flogo` | `1.19.0` |
| `tibco-cp-devhub` | `1.19.0` |
| `tibco-cp-hawk` | `1.19.23` |
| `tibco-cp-messaging` | `1.19.23` |
| `tibco-developer-hub` | `1.19.8` |
| `tp-cp-proxy` | `1.19.1` |
| `tp-dp-monitor-agent` | `1.19.11` |
| `o11yservice` | `1.19.16` |
| `jaeger` | `4.8.2` |
| `dp-configure-namespace` | `1.19.10` |
| `dp-core-infrastructure` | `1.19.5` |
| `tp-dp-infra-mcp-server` | `1.19.0` |

## New in v1.19.0

### Values Check Before Upgrade

```bash
grep -n "createDeprecatedPolicies" cp-values.yaml && echo "REMOVE this key (removed in 1.19.0)"
yq '.["otel-collector"].enabled' cp-values.yaml     # default flipped to true in 1.19.0 - set explicitly
```

### PCP-23331 Workaround (CP logs missing in Elasticsearch after upgrade)

```bash
kubectl edit configmap otel-services -n cp1-ns
#   exporters.elasticsearch/log.mapping.mode: none
#   remove transform/es-bodymap from the logs pipeline
kubectl rollout restart deployment cp-otel-services -n cp1-ns
```

### Gateway API (hybrid-proxy route fixed)

```bash
kubectl get httproute -n cp1-ns hybrid-proxy -o jsonpath='{.spec.rules[*].matches[*].path.value}{"\n"}'
# simplified DNS (dnsDomain == dnsTunnelDomain): /infra/tunnel
# split DNS:                                     /infra/tunnel /
```

### Infra MCP Server RBAC

```bash
kubectl get role,clusterrole -A | grep -i infra-mcp
# cluster-wide diagnostics: --set rbac.infraMcpClusterScoped=true on dp-configure-namespace
```

## Upgrade Order (from 1.18.0)

1. Back up Helm values and database state.
2. Remove `createDeprecatedPolicies`; set `otel-collector.enabled`.
3. Upgrade `tibco-cp-base` to 1.19.0 (`scripts/1.19.0/upgrade.sh` or `helm upgrade --version 1.19.0`).
4. Upgrade BW, Flogo, Developer Hub to 1.19.0; Hawk and Messaging to 1.19.23.
5. Upgrade Data Plane infrastructure from the Control Plane UI, then capabilities.
6. Continue with the [1.20.0 quick reference](../v1.20/QUICK-REFERENCE).

## Official References

- [TIBCO Platform 1.19.0 Documentation](https://docs.tibco.com/pub/platform-cp/1.19.0/doc/html/Default.htm)
- [Official 1.19.0 New Features](https://docs.tibco.com/pub/platform-cp/1.19.0/doc/html/Release-Notes/new-features.htm)
- [Official 1.19.0 Known Issues](https://docs.tibco.com/pub/platform-cp/1.19.0/doc/html/Release-Notes/known-issues.htm)
- [TIBCO tp-helm-charts](https://github.com/TIBCOSoftware/tp-helm-charts)
