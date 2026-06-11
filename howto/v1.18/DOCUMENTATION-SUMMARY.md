# TIBCO Platform v1.18.0 Documentation Summary

**Date**: June 11, 2026
**Status**: Documentation updated for 1.18.0 release

## Files Added

```text
howto/v1.18/
├── how-to-cp-and-dp-aks-setup-guide.md
├── QUICK-REFERENCE.md
└── DOCUMENTATION-SUMMARY.md

releases/
└── v1.18.0.md
```

## Key Changes from v1.17.0 to v1.18.0

| Area | 1.18.0 Change | AKS Impact |
|------|---------------|------------|
| Gateway API | Gateway API Controller support for Control Tower data planes | Validate GatewayClass/Gateway/HTTPRoute objects when using Gateway API |
| BW5/BW6 | Traefik Gateway API support and `Other` Gateway API controller option | AKS Traefik users can evaluate Gateway API endpoint exposure |
| Flogo | Traefik Gateway API, NetScaler Gateway, and namespace-level RBAC enforcement | Review application endpoint and namespace permission behavior |
| RBAC | Namespace-level RBAC for Application Manager and Application Viewer | Inventory namespaces and update role assignments after upgrade |
| Email | Email server configuration moved to Platform Console | Configure MailDev or SMTP from UI after install/upgrade |
| Alerts | Alerts Audit Trail page | Add alert audit validation to post-upgrade checks |
| Developer Hub | Self-service flows | Upgrade Developer Hub charts with the release |

## Component Versions

| Component | v1.17.0 | v1.18.0 |
|-----------|---------|---------|
| `tibco-cp-base` | `1.17.0` | `1.18.0` |
| `tibco-cp-bw` | `1.17.0` | `1.18.0` |
| `tibco-cp-flogo` | `1.17.0` | `1.18.0` |
| `tibco-cp-devhub` | `1.17.0` | `1.18.0` |
| `tibco-cp-hawk` | `1.17.x` | `1.18.12` |
| `tibco-developer-hub` | `1.17.12` | `1.18.12` |
| `tp-cp-proxy` | `1.17.4` | `1.18.0` |
| `tp-dp-monitor-agent` | `1.17.13` | `1.18.9` |
| `o11yservice` | `1.17.16` | `1.18.13` |

## Documentation Updates

- README now lists 1.18.0 as the current recommended release.
- 1.16.0 now has a versioned CP+DP guide entry point so existing 1.16 details remain discoverable.
- 1.17.0 now has a versioned CP+DP guide entry point for the missed 1.17 release changes.
- Shared observability and reference links now point to versioned 1.18 official docs where appropriate.

## Official Sources

- [TIBCO Platform Control Plane 1.18.0 Documentation](https://docs.tibco.com/pub/platform-cp/1.18.0/doc/html/Default.htm)
- [Official 1.18.0 New Features](https://docs.tibco.com/pub/platform-cp/1.18.0/doc/html/Release-Notes/new-features.htm)
- [Official 1.18.0 Known Issues](https://docs.tibco.com/pub/platform-cp/1.18.0/doc/html/Release-Notes/known-issues.htm)
- [TIBCO tp-helm-charts repository](https://github.com/TIBCOSoftware/tp-helm-charts)