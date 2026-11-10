# TIBCO Platform 1.22.0 Quick Reference (AKS)

Use this page alongside the [1.22.0 release notes](../../releases/v1.22.0), the shared [AKS CP + DP setup guide](../how-to-cp-and-dp-aks-setup-guide), and the [official 1.22.0 documentation](https://docs.tibco.com/pub/platform-cp/1.22.0/doc/html/Default.htm).

## Upgrade sequence from 1.21.0

1. Back up PostgreSQL, Helm values, Kubernetes secrets, and record `helm history`.
2. For custom registries, mirror the 1.22.0 images from the official artifact manifests before upgrading.
3. Run the official [1.22.0 upgrade assistant](https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/scripts/1.22.0). It requires a deployed Control Plane at `app_version` 1.21.0.
4. Upgrade decoupled Control Plane capability charts using the exact artifact versions.
5. Upgrade Data Plane infrastructure and capabilities (including observability) through the Control Plane UI; prefer its generated commands.
6. Verify chart versions and workload health.

The assistant requires Bash 4+, yq 4.45.4+, Helm 3.17+ and jq 1.8+ for Helm flows, and kubectl for readiness checks. Its documented value change merges `tp-cp-o11y.capabilities.o11y.default` and `.withResources` into `tp-cp-o11y.capabilities.o11y` (`overwriteRecipe`); do this by hand if you upgrade with manual Helm commands. Review custom-registry image contents before use.

## 1.22.0 reference chart versions

| Chart | Version |
|---|---:|
| `tibco-cp-base` | 1.22.0 |
| `tibco-cp-bw` / `tibco-cp-flogo` / `tibco-cp-devhub` | 1.22.0 |
| `tibco-cp-hawk` / `tibco-cp-messaging` | 1.22.14 / 1.22.14 |
| `tibco-cp-mcp-hub` / `tp-mcp-gateway` | 1.22.0 / 1.22.4 |
| `tibco-cp-addon-eventprocessing` | 1.22.0 |
| `dp-configure-namespace` / `dp-core-infrastructure` | 1.22.3 / 1.22.5 |
| `tibco-developer-hub` | 1.22.12 |
| `tp-dp-monitor-agent` / `o11yservice` | 1.22.5 / 1.22.29 |
| `jaeger` / `opentelemetry-collector` | 4.8.5 / 0.156.5 |
| EMS / ActiveSpaces charts | `msg-ems-tp` 1.22.14 / `msg-activespaces-tp` 1.22.14 |

Consult all 1.22.0 artifact files for charts not listed here and for the exact images to mirror.

## 1.22 operations to account for

- NGINX Ingress usage was removed from TIBCO Operated Control Plane; TIBCO no longer officially supports or recommends it with the Control Plane and Data Planes. Use Traefik (workshop default) or a supported Gateway API controller.
- The Data Plane registration form and per-Data-Plane hybrid connectivity are as in 1.21: if you disable hybrid connectivity, **Reachable DP URL** must be the Data Plane `cpdpproxy` service URL reachable from the Control Plane, not the application ingress FQDN. Use the UI-generated commands. See the [official 1.22 registration guide](https://docs.tibco.com/pub/platform-cp/1.22.0/doc/html/UserGuide/registering-an-existing-kubernetes-cluster.htm).
- Infrastructure component CPU, memory, and storage can be overridden from the Data Plane configuration page (YAML editor). Per PCP-26766, customized observability values reset when you later update the observability resource configuration.
- The Application Operator permission (start, stop, restart, scale, environment variables; no delete) can be scoped to a namespace; it is supported for BW5 and BW6 Containers.
- Application logs can be downloaded from the application details page; for Data Planes not yet upgraded to 1.22 (including observability) the download fails with 404 (PCP-25998).
- TESSA can use Amazon Bedrock instead of an OpenAI API key, and supports the EMS MCP server.
- Optional after upgrade: remove the stale `capabilities/platform/o11y-exporter.yaml` recipe from the Control Plane PVC (no functional impact either way); do not use the `o11y-service` pod to check for it.

## Known issue checks

- PCP-26766: customized observability recipe values reset after updating the observability resource configuration; no workaround.
- PCP-25998: log download returns 404 for apps on a not-yet-upgraded Data Plane; upgrade the Data Plane and its observability capability.
- PCP-27651: Capability Provisioner and Fluent Bit sidecar error logs after upgrading Data Plane infrastructure to 1.22.0 (BW6 Containers); no workaround listed.
- PLTDX-1343: use `azure-disk-sc`, not `azure-files-sc`, for Developer Hub PostgreSQL.

Review the [official known issues](https://docs.tibco.com/pub/platform-cp/1.22.0/doc/html/Release-Notes/known-issues.htm) before upgrading.
