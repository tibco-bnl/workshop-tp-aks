# TIBCO Platform 1.20.0 CP and DP Setup on AKS

Use this guide as the 1.20.0 overlay for the shared AKS CP+DP setup. The common AKS preparation flow remains the same: create or connect to AKS, install ingress/storage, configure PostgreSQL, DNS, certificates, and then deploy Control Plane and Data Plane charts. The sections below document what changes for 1.20.0 (and what changed in the skipped 1.19.0 release).

## Start Here

1. Complete the shared baseline guide for AKS infrastructure and common prerequisites: [../how-to-cp-and-dp-aks-setup-guide.md](../how-to-cp-and-dp-aks-setup-guide).
2. If upgrading from 1.18.0, apply the [1.19.0 overlay](../v1.19/how-to-cp-and-dp-aks-setup-guide) first; 1.19.0 is the only supported direct upgrade source for 1.20.0.
3. Refresh Helm repositories.

```bash
helm repo add tibco-platform https://tibcosoftware.github.io/tp-helm-charts
helm repo update tibco-platform
```

## 1.20.0 Chart Versions

These versions are from the 1.20.0 artifact manifests in the official `tp-helm-charts` repository.

| Area | Chart | Version |
|------|-------|---------|
| Control Plane | `tibco-cp-base` | `1.20.0` |
| Control Plane | `tp-cp-proxy` | `1.20.2` |
| Control Plane | `artifactmanager` | `1.20.0` |
| Control Plane | `o11yservice` | `1.20.5` |
| Control Plane | `tp-dp-monitor-agent` | `1.20.2` |
| Control Plane | `jaeger` | `4.8.3` |
| Data Plane | `dp-configure-namespace` | `1.20.0` |
| Data Plane | `dp-core-infrastructure` | `1.20.3` |
| BW | `tibco-cp-bw` | `1.20.0` |
| BW | `bwprovisioner` / `bw5provisioner` | `1.20.2` |
| BW | `dp-bwce-app` / `dp-bw5ce-app` | `1.20.4` |
| Flogo | `tibco-cp-flogo` | `1.20.0` |
| Flogo | `flogoprovisioner` | `1.20.10` |
| Flogo | `dp-flogo-app` | `1.20.8` |
| Developer Hub | `tibco-cp-devhub` | `1.20.0` |
| Developer Hub | `tibco-developer-hub` | `1.20.8` |
| Hawk | `tibco-cp-hawk` / `tp-dp-hawk-console` | `1.20.8` |
| Messaging | `tibco-cp-messaging` / `msg-ems-tp` | `1.19.23` (no 1.20.0 release) |
| MCP | `tp-dp-infra-mcp-server` | `1.20.0` |
| MCP | `tp-mcp-gateway` | `1.20.0` (MCP Hub, TIBCO Operated CP only) |

## AKS Changes from 1.18.0

### Control Plane Base Chart

```bash
export TP_CP_BASE_CHART_VERSION="1.20.0"

helm upgrade --install --wait --timeout 1h \
  -n ${CP_INSTANCE_ID}-ns platform-base tibco-cp-base \
  --labels layer=5 \
  --repo "${TP_TIBCO_HELM_CHART_REPO}" \
  --version "${TP_CP_BASE_CHART_VERSION}" \
  --values cp-values.yaml
```

### Values File Changes Since 1.18.0

Review `cp-values*.yaml` for these keys before installing or upgrading:

```yaml
global:
  tibco:
    networkPolicy:
      # REMOVED in 1.19.0 - delete this key if present
      # createDeprecatedPolicies: true
      createClusterScopePolicies: true

    # NEW in 1.20.0 (chart default shown). MFT adapter is disabled by default.
    # Set to [] to keep every mandatory infra capability enabled.
    disabledInfraCapabilities: [MFTADAPTER]

otel-collector:
  # Chart default: false in 1.18.0, true in 1.19.0, false again in 1.20.0.
  # Set it explicitly. true requires a reachable log server (audit log, CP Fluent Bit logging).
  enabled: true
```

The shared guide's `cp-values*.yaml` examples already set `otel-collector.enabled: true`; make sure the Elasticsearch/OpenSearch log server from the observability guide is reachable, or set it to `false`.

### Simplified DNS Continues

Use one Control Plane base domain, for example `platform.azure.example.com`, with `global.external.dnsDomain` and `global.external.dnsTunnelDomain` set to the same value, one wildcard DNS record, and one wildcard certificate. Split `cp1-my` / `cp1-tunnel` domains remain supported for legacy installations.

### Gateway API: hybrid-proxy Route Fixed Since 1.19.0

`tibco-cp-base` 1.19.0 changed the `hybrid-proxy` HTTPRoute template: it always renders `PathPrefix: /infra/tunnel` and adds `PathPrefix: /` only when `dnsDomain != dnsTunnelDomain` (fix for PCP-21362). With simplified DNS both `hybrid-proxy` and `router-operator` can attach to `*.<base-domain>` on the same Gateway; the longer `/infra/tunnel` match wins for tunnel traffic.

The chart never reads `gatewayRoute.rules` from values. Remove the explicit rules that the 1.18 workaround added and use the shared wildcard hostname:

```yaml
hybrid-proxy:
  enabled: true
  ingress:
    enabled: false
  gatewayRoute:
    enabled: true
    controllerName: "${TP_GATEWAY_CLASS}"        # nginx (NGINX Gateway Fabric) or traefik
    hostnames:
    - '*.${CP_MY_DNS_DOMAIN}'
    parentRefs:
    - name: "${TP_GATEWAY_NAME}"
      namespace: "${TP_GATEWAY_NAMESPACE}"

router-operator:
  ingress:
    enabled: false
  gatewayRoute:
    enabled: true
    controllerName: "${TP_GATEWAY_CLASS}"
    hostnames:
    - '*.${CP_MY_DNS_DOMAIN}'
    parentRefs:
    - name: "${TP_GATEWAY_NAME}"
      namespace: "${TP_GATEWAY_NAMESPACE}"

global:
  external:
    dnsDomain: "${TP_BASE_DNS_DOMAIN}"
    dnsTunnelDomain: "${TP_BASE_DNS_DOMAIN}"
```

Verify:

```bash
kubectl get httproute -n ${CP_INSTANCE_ID}-ns hybrid-proxy \
  -o jsonpath='{.spec.hostnames}{"  "}{.spec.rules[*].matches[*].path.value}{"\n"}'
# expected with simplified DNS: /infra/tunnel
```

The official Gateway API controller matrix is unchanged: NGINX Gateway Fabric 2.3.0, Istio 1.28.2, Traefik `traefik-39.0.7`, NetScaler `netscaler-cpx-with-gateway-controller-2.0.0`. For AKS workshops that already use Traefik ingress, keep Traefik for the baseline and evaluate Gateway API where the capability supports it.

### Data Plane Infrastructure

Use the commands generated by the Control Plane UI. For 1.20.0 they reference `dp-configure-namespace` 1.20.0 and `dp-core-infrastructure` 1.20.3. `dp-configure-namespace` no longer accepts `networkPolicy.createDeprecatedPolicies`; remove that `--set` from saved commands. New RBAC toggles `rbac.infraMcp`, `rbac.mcpGateway`, `rbac.springboot` default to `true`; `rbac.infraMcpClusterScoped` defaults to `false`.

### Control Plane Rollback

New in 1.20.0. Record the current revision before upgrading:

```bash
helm history platform-base -n ${CP_INSTANCE_ID}-ns
```

If the upgrade fails and `global.tibco.manageDbSchema` is `true` (workshop default):

```bash
helm rollback platform-base <revision> -n ${CP_INSTANCE_ID}-ns --wait
```

If `manageDbSchema` is `false`, run `postgres-helper.bash rollbackDbSchema <chart-version>` from `tp-helm-charts/scripts/database` first. Roll back the Control Plane before upgrading any Data Plane or capability.

### Storage for Developer Hub

Use the Azure Disk class (`managed-premium` in this workshop, `azure-disk-sc` upstream) for the Developer Hub PostgreSQL pod. `azure-files-sc` fails on `chmod` (PLTDX-1343).

### Email Server Configuration

Unchanged since 1.18.0. Keep MailDev running and configure `development-mailserver.tibco-ext.svc.cluster.local`, port `1025`, TLS disabled, in the Platform Console. Do not add email Helm values.

### OTLP Exporters with Custom Headers

When an OTLP exporter or query service in Data Plane Configuration > Observability needs tenant or authorization headers, add them in the new Custom Header fields. The secondary exporter supports OTLP only.

### MCP Hub, Infra MCP Server, and TESSA

MCP Hub and TESSA are TIBCO Operated Control Plane features in 1.20.0 and do not apply to a self-hosted AKS Control Plane. The Infra MCP Server can still be provisioned as a Data Plane capability (Data Planes > Capabilities > Add Capability); it exposes read-only `kubectl` and `helm` diagnostics through the Data Plane proxy.

### Upstream AKS Tooling Changes

The upstream `tp-helm-charts` AKS workshop for 1.20.0 uses Azure CLI 2.88.0, kubectl v1.34.3, Helm v3.18.0, `TP_KUBERNETES_VERSION="1.35"`, and pins the preview extension:

```bash
# Unpinned aks-preview can break `az aks create` ("ValueError: too many values to unpack")
az extension add --name aks-preview --version 21.0.0b10
```

The highest AKS version certified by TIBCO for the Control Plane cluster in 1.20.0 is 1.33; use 1.33 for supported Control Plane deployments and treat 1.35 as the upstream workshop's evaluation setting.

## Upgrade Checklist from 1.19.0

- [ ] Back up Helm values, secrets, and database state; record `helm history`.
- [ ] `createDeprecatedPolicies` is absent; `otel-collector.enabled` and `disabledInfraCapabilities` are set intentionally.
- [ ] Upgrade `tibco-cp-base` to 1.20.0 (or run `scripts/1.20.0/upgrade.sh`).
- [ ] Upgrade `tibco-cp-bw`, `tibco-cp-flogo`, `tibco-cp-devhub` to 1.20.0 and `tibco-cp-hawk` to `1.20.*`; leave `tibco-cp-messaging` at 1.19.23.
- [ ] Upgrade Data Plane infrastructure (`dp-configure-namespace` 1.20.0, `dp-core-infrastructure` 1.20.3), then capabilities; do not leave capabilities behind.
- [ ] Validate HTTPRoutes if Gateway API is used.
- [ ] Run `scripts/verify-release.sh` from `tp-helm-charts` for `control-plane` 1.20.0.
- [ ] Review 1.20.0 known issues before production use.

## Known Issues to Watch on AKS

- PCP-23615: deleting a Data Plane's observability configuration fails after upgrading to 1.20.0 (no workaround).
- PCP-20148: traces older than the Jaeger v2 move show as red dots.
- PLTDX-1459: Control Plane and Developer Hub on the same cluster with Traefik and identical hostnames return 404; use distinct FQDNs.
- PLTDX-1343: `azure-files-sc` breaks the Developer Hub PostgreSQL pod.
- BWCE-11307: Swagger tester for BW6 apps created on 1.17.0 and exposed via `traefik-gateway` needs capability and app upgrades.

## References

- [TIBCO Platform 1.20.0 Release Notes](../../releases/v1.20.0)
- [TIBCO Platform 1.20.0 Quick Reference](./QUICK-REFERENCE)
- [TIBCO Platform 1.19.0 Setup Overlay](../v1.19/how-to-cp-and-dp-aks-setup-guide)
- [TIBCO Platform Control Plane 1.20.0 Documentation](https://docs.tibco.com/pub/platform-cp/1.20.0/doc/html/Default.htm)
- [Official 1.20.0 New Features](https://docs.tibco.com/pub/platform-cp/1.20.0/doc/html/Release-Notes/new-features.htm)
- [Official 1.20.0 Known Issues](https://docs.tibco.com/pub/platform-cp/1.20.0/doc/html/Release-Notes/known-issues.htm)
- [TIBCO tp-helm-charts repository](https://github.com/TIBCOSoftware/tp-helm-charts)
