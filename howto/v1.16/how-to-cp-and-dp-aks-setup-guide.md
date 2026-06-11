# TIBCO Platform 1.16.0 CP and DP Setup on AKS

This is the archived entry point for TIBCO Platform Control Plane 1.16.0 on AKS. Use it when you need to reproduce or maintain a 1.16.0 environment without picking up later 1.17.0 or 1.18.0 release behavior.

## Use This Version When

- You are maintaining an existing 1.16.0 Control Plane installation.
- You need the 1.16.0 container registry, DNS, and values examples captured from the `dp1-aks-aauk-kul` environment.
- You are preparing to upgrade from 1.16.0 to 1.17.0 or 1.18.0 and need the before-state documented.

## 1.16.0 Baseline

- Full setup guide baseline: [../how-to-cp-and-dp-aks-setup-guide.md](../how-to-cp-and-dp-aks-setup-guide.md)
- Installation scripts and values: [../../scripts/v1.16.0-cpdp-install/README.md](../../scripts/v1.16.0-cpdp-install/README.md)
- Values guide: [../../scripts/v1.16.0-cpdp-install/values/VALUES-GUIDE.md](../../scripts/v1.16.0-cpdp-install/values/VALUES-GUIDE.md)
- Release notes: [../../releases/v1.16.0.md](../../releases/v1.16.0.md)
- Quick reference: [QUICK-REFERENCE.md](QUICK-REFERENCE.md)
- Documentation summary: [DOCUMENTATION-SUMMARY.md](DOCUMENTATION-SUMMARY.md)

## Important 1.16.0 Settings

| Area | 1.16.0 Value |
|------|--------------|
| Control Plane chart | `tibco-cp-base:1.16.0` |
| BW capability chart | `tibco-cp-bw:1.16.0` |
| Flogo capability chart | `tibco-cp-flogo:1.16.0` |
| Developer Hub chart | `tibco-cp-devhub:1.16.0` |
| Container registry | `csgprdusw2reposaas.jfrog.io` |
| Container repository | `tibco-platform-docker-dev` |
| Ingress controller | Traefik recommended |
| DNS model | Simplified single-level subdomains from 1.15.0 onward |

## Upgrade Next Steps

- For 1.16.0 to 1.17.0 changes, review [../../releases/v1.17.0.md](../../releases/v1.17.0.md) and [../v1.17/how-to-cp-and-dp-aks-setup-guide.md](../v1.17/how-to-cp-and-dp-aks-setup-guide.md).
- For 1.17.0 to 1.18.0 changes, review [../../releases/v1.18.0.md](../../releases/v1.18.0.md) and [../v1.18/how-to-cp-and-dp-aks-setup-guide.md](../v1.18/how-to-cp-and-dp-aks-setup-guide.md).

## Official References

- [TIBCO Platform Control Plane 1.16.0 Documentation](https://docs.tibco.com/pub/platform-cp/1.16.0/doc/html/Default.htm)
- [TIBCO tp-helm-charts repository](https://github.com/TIBCOSoftware/tp-helm-charts)