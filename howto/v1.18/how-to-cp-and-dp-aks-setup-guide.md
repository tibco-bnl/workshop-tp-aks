# TIBCO Platform 1.18.0 CP and DP Setup on AKS

Use this guide as the 1.18.0 overlay for the shared AKS CP+DP setup. The common AKS preparation flow remains the same: create or connect to AKS, install ingress/storage, configure PostgreSQL, DNS, certificates, and then deploy Control Plane and Data Plane charts. The sections below document what changes for 1.18.0.

## Start Here

1. Complete the shared baseline guide for AKS infrastructure and common prerequisites: [../how-to-cp-and-dp-aks-setup-guide.md](../how-to-cp-and-dp-aks-setup-guide).
2. If upgrading, upgrade 1.16.0 to 1.17.0 first, then apply this 1.18.0 overlay.
3. Refresh Helm repositories.

```bash
helm repo add tibco-platform https://tibcosoftware.github.io/tp-helm-charts
helm repo update tibco-platform
```

## 1.18.0 Chart Versions

These versions are from the 1.18.0 artifacts in the official `tp-helm-charts` repository.

| Area | Chart | Version |
|------|-------|---------|
| Control Plane | `tibco-cp-base` | `1.18.0` |
| Control Plane | `tp-cp-proxy` | `1.18.0` |
| Control Plane | `artifactmanager` | `1.18.1` |
| Control Plane | `o11yservice` | `1.18.13` |
| Control Plane | `tp-dp-monitor-agent` | `1.18.9` |
| BW | `tibco-cp-bw` | `1.18.0` |
| BW | `bwprovisioner` | `1.18.4` |
| BW | `bw5provisioner` | `1.18.4` |
| BW | `dp-bwce-app` | `1.18.4` |
| BW | `dp-bw5ce-app` | `1.18.4` |
| Flogo | `tibco-cp-flogo` | `1.18.0` |
| Flogo | `flogoprovisioner` | `1.18.4` |
| Flogo | `dp-flogo-app` | `1.18.10` |
| Developer Hub | `tibco-cp-devhub` | `1.18.0` |
| Developer Hub | `tibco-developer-hub` | `1.18.12` |
| Hawk | `tibco-cp-hawk` | `1.18.12` |
| Hawk | `tp-dp-hawk-console` | `1.18.12` |

## AKS Changes from 1.17.0

### Simplified DNS Continues in 1.18.0

The simplified DNS model remains the recommended AKS pattern for 1.18.0. Use one Control Plane base domain, for example `platform.azure.example.com`, instead of separate `cp1-my` and `cp1-tunnel` base domains when your environment allows it.

Recommended 1.18.0 pattern:

- Platform Console: `https://admin.platform.azure.example.com`
- Subscription URL: `https://<hostPrefix>.platform.azure.example.com`
- Control Plane chart values: set `global.external.dnsDomain` and `global.external.dnsTunnelDomain` to the same base domain
- DNS and certificate: one wildcard record/certificate for `*.platform.azure.example.com`
- Tunnel routing: handled by the `hybrid-proxy` `/infra/tunnel` route on the same base domain

Use split `cp1-my` and `cp1-tunnel` domains only for legacy installations or environments that require separate DNS/certificate ownership.

### Gateway API Controller Support

1.18.0 adds Gateway API Controller support for Control Tower data planes. BW5, BW6, and Flogo can use Traefik Gateway API for public endpoints, and BW5/BW6 can select `Other` for third-party Gateway API controllers already installed in the cluster.

For AKS workshops that already use Traefik, keep the existing Traefik ingress controller for standard ingress and evaluate Gateway API for application endpoint exposure where capability configuration supports it.

### Namespace-Level RBAC

Namespace-level RBAC is introduced for Kubernetes data planes. Namespaces become Data Plane resources under Data Plane Configuration > Resources, and Application Manager/Application Viewer permissions can be scoped by capability and namespace.

Before upgrading shared workshop clusters:

- Inventory namespaces that host BW, Flogo, EMS, and other applications.
- Confirm Application Manager and Application Viewer role assignments after upgrade.
- Avoid assuming a user with application permissions can deploy into newly created namespaces unless that namespace is explicitly granted.

### Email Server Configuration Moves to Console

Email server configuration is moved from `tibco-cp-base` chart values to the TIBCO Platform Console UI. After a fresh install or upgrade, configure the email server in the Platform Console to send and receive Control Plane emails.

For workshop environments that use MailDev, keep the MailDev service, but configure its SMTP host and port in the Console instead of relying only on chart values.

### Alert Audit Trail

1.18.0 adds an Alerts Audit Trail page. If you use alerting in AKS, include alert history validation in post-upgrade checks.

### Developer Hub Self-Service Flows

Developer Hub adds self-service flows for reusable platform automation. No AKS infrastructure change is required, but Developer Hub chart versions should be upgraded together with the Control Plane release.

## Upgrade Checklist from 1.17.0

- [ ] Back up Helm values and database state.
- [ ] Upgrade Control Plane infrastructure charts to 1.18.0-compatible versions.
- [ ] Upgrade Data Plane and capabilities to 1.18.0-compatible versions; do not leave capabilities behind after infrastructure upgrade.
- [ ] Configure email server in TIBCO Platform Console.
- [ ] Review namespace-level RBAC assignments for Application Manager and Application Viewer roles.
- [ ] If using Traefik Gateway API, validate GatewayClass, Gateway, HTTPRoute, and application endpoint behavior.
- [ ] Validate Alert Audit Trail events.
- [ ] Review 1.18.0 known issues before production use.

## Known Issues to Watch on AKS

- Existing 1.17.0 Data Planes can show incorrect Integration Summary and Application Instance card data after Control Plane upgrade until the Data Plane is upgraded to 1.18.0.
- Traces and application service metrics have known limitations with Traefik in some Control Tower data plane environments.
- Some BW6 and Flogo known issues are capability-version dependent; upgrade the capability and application charts together.

## References

- [TIBCO Platform 1.18.0 Release Notes](../../releases/v1.18.0)
- [TIBCO Platform 1.18.0 Quick Reference](./QUICK-REFERENCE)
- [TIBCO Platform Control Plane 1.18.0 Documentation](https://docs.tibco.com/pub/platform-cp/1.18.0/doc/html/Default.htm)
- [Official 1.18.0 New Features](https://docs.tibco.com/pub/platform-cp/1.18.0/doc/html/Release-Notes/new-features.htm)
- [Official 1.18.0 Known Issues](https://docs.tibco.com/pub/platform-cp/1.18.0/doc/html/Release-Notes/known-issues.htm)
- [TIBCO tp-helm-charts repository](https://github.com/TIBCOSoftware/tp-helm-charts)