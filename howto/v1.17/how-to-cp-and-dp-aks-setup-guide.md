# TIBCO Platform 1.17.0 CP and DP Setup on AKS

Use this guide as the 1.17.0 overlay for the common AKS CP+DP setup. The base cluster, DNS, storage, PostgreSQL, certificate, and Traefik steps remain the same as the shared [CP and DP setup guide](../how-to-cp-and-dp-aks-setup-guide.md). Apply the differences below when deploying or upgrading to TIBCO Platform Control Plane 1.17.0.

## Start Here

1. Complete the shared baseline through ingress, storage, PostgreSQL, DNS, and certificates: [../how-to-cp-and-dp-aks-setup-guide.md](../how-to-cp-and-dp-aks-setup-guide.md).
2. Use 1.16.0 as the direct upgrade source when upgrading an existing environment: [../v1.16/how-to-cp-and-dp-aks-setup-guide.md](../v1.16/how-to-cp-and-dp-aks-setup-guide.md).
3. Update Helm repositories before installing or upgrading charts.

```bash
helm repo add tibco-platform https://tibcosoftware.github.io/tp-helm-charts
helm repo update tibco-platform
```

## 1.17.0 Chart Versions

| Component | Chart Version |
|-----------|---------------|
| Control Plane base | `tibco-cp-base:1.17.0` |
| BW capability | `tibco-cp-bw:1.17.0` |
| Flogo capability | `tibco-cp-flogo:1.17.0` |
| Developer Hub | `tibco-cp-devhub:1.17.0` |
| Event Processing add-on | `tibco-cp-addon-eventprocessing:1.17.0` |
| DP monitor agent | `tp-dp-monitor-agent:1.17.13` |
| DP license file | `tp-dp-license-file:1.17.0` |
| CP proxy | `tp-cp-proxy:1.17.4` |

## AKS Changes from 1.16.0

### Simplified DNS Baseline

Use the simplified Control Plane DNS model for new 1.17.0 AKS installs and carry it forward to 1.18.0. Instead of separate `cp1-my` and `cp1-tunnel` base domains, use one base domain such as `platform.azure.example.com`:

- Platform Console: `https://admin.platform.azure.example.com`
- Subscription URL: `https://<hostPrefix>.platform.azure.example.com`
- Helm values: set `global.external.dnsDomain` and `global.external.dnsTunnelDomain` to the same base domain
- DNS/certificate: one wildcard record and certificate for `*.platform.azure.example.com`
- Hybrid connectivity: tunnel traffic uses the same wildcard domain and the `/infra/tunnel` route

Keep split `cp1-my` and `cp1-tunnel` domains only for legacy environments or if DNS/certificate ownership must remain separate.

### Webhook Receiver for Alerts

If you configure webhook alert receivers, allow egress from the Control Plane namespace to the external webhook endpoint.

```bash
kubectl run curl-test -n cp1-ns --rm -it --image=curlimages/curl -- \
  curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"source":"tibco-platform-aks","test":true}'
```

### OpenSearch Observability

1.17.0 can use OpenSearch for Jaeger traces and service logs. Existing Elasticsearch/ECK deployments can remain in place. If you switch to OpenSearch, apply the official index templates before connecting TIBCO Platform.

### BW5CE Hawk REST API

BW5CE exposes Hawk methods on port `8090` under `/commands`. Add NetworkPolicy rules if your Data Plane namespace uses restrictive policies.

```yaml
ports:
  - port: 8090
    protocol: TCP
```

### Fluentbit Customization

BW5, BW6, and Flogo capabilities can use custom Fluentbit configuration. Store any custom log pipeline snippets with the capability values or recipe configuration used during provisioning.

## Upgrade Checklist from 1.16.0

- [ ] Back up Helm values for every release in `cp1-ns` and Data Plane namespaces.
- [ ] Confirm the registry remains `csgprdusw2reposaas.jfrog.io` unless your TIBCO account team provides a different regional registry.
- [ ] Upgrade Control Plane base and capability charts to the 1.17.0 versions listed above.
- [ ] If using OpenSearch, apply index templates before enabling it for traces or logs.
- [ ] If using webhook alerts, verify outbound connectivity from `cp1-ns`.
- [ ] If using BW5CE and NetworkPolicy, allow port `8090` as needed.

## References

- [TIBCO Platform 1.17.0 Release Notes](../../releases/v1.17.0.md)
- [TIBCO Platform 1.17.0 Quick Reference](QUICK-REFERENCE.md)
- [TIBCO Platform Control Plane 1.17.0 Documentation](https://docs.tibco.com/pub/platform-cp/1.17.0/doc/html/Default.htm)
- [Official 1.17.0 New Features](https://docs.tibco.com/pub/platform-cp/1.17.0/doc/html/Release-Notes/new-features.htm)
- [TIBCO tp-helm-charts repository](https://github.com/TIBCOSoftware/tp-helm-charts)