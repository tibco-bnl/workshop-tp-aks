# TIBCO Platform v1.18.0 Quick Reference Guide

**TIBCO Platform Version**: 1.18.0 | **Status**: Current release

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
| `tibco-cp-base` | `1.18.0` |
| `tibco-cp-bw` | `1.18.0` |
| `tibco-cp-flogo` | `1.18.0` |
| `tibco-cp-devhub` | `1.18.0` |
| `tibco-cp-hawk` | `1.18.12` |
| `tibco-developer-hub` | `1.18.12` |
| `tp-cp-proxy` | `1.18.0` |
| `tp-dp-monitor-agent` | `1.18.9` |
| `o11yservice` | `1.18.13` |

## New in v1.18.0

### Gateway API Checks

```bash
kubectl get gatewayclass
kubectl get gateway -A
kubectl get httproute -A
kubectl describe gatewayclass <gateway-class-name>
```

Use this when testing Traefik Gateway API or another Gateway API controller for BW5, BW6, or Flogo application endpoints.

### Namespace-Level RBAC Checks

```bash
kubectl get ns
kubectl get rolebinding,clusterrolebinding -A | grep -i tibco
```

After upgrade, review Application Manager and Application Viewer role assignments in the TIBCO Platform Console because namespace-level access is explicit in 1.18.0.

### Email Server Configuration

Email server settings are configured in TIBCO Platform Console in 1.18.0. For MailDev workshop setups, keep the service running and configure the Console with:

| Field | Example |
|-------|---------|
| SMTP host | `development-mailserver.tibco-ext.svc.cluster.local` |
| SMTP port | `1025` |
| TLS | Disabled for MailDev |

### Alert Audit Trail

After configuring alerts, validate audit trail entries from the UI and confirm alert pods are healthy.

```bash
kubectl get pods -n cp1-ns | grep -i alert
kubectl logs -n cp1-ns -l app=alerts-service --tail=100
```

## Upgrade Order

1. Back up Helm values and database state.
2. Upgrade Control Plane infrastructure.
3. Upgrade Data Plane components.
4. Upgrade BW, Flogo, Developer Hub, Hawk, and other capabilities.
5. Configure email in the Platform Console.
6. Re-check namespace-level RBAC and Gateway API endpoints.

## Official References

- [TIBCO Platform 1.18.0 Documentation](https://docs.tibco.com/pub/platform-cp/1.18.0/doc/html/Default.htm)
- [Official 1.18.0 New Features](https://docs.tibco.com/pub/platform-cp/1.18.0/doc/html/Release-Notes/new-features.htm)
- [Official 1.18.0 Known Issues](https://docs.tibco.com/pub/platform-cp/1.18.0/doc/html/Release-Notes/known-issues.htm)
- [TIBCO tp-helm-charts](https://github.com/TIBCOSoftware/tp-helm-charts)