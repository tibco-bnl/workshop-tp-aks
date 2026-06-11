# TIBCO Platform on Azure Kubernetes Service (AKS) Workshop

Guides and supporting resources for deploying TIBCO Platform Control Plane and Data Plane on Azure Kubernetes Service.

> **Current release:** [v1.18.0](./releases/v1.18.0) | **TIBCO Platform CP:** 1.18.0<br>
> **Upgrade path:** [1.17.0 to 1.18.0](./releases/v1.18.0#upgrade-path-from-v1170)<br>
> **Official charts:** [TIBCO tp-helm-charts](https://github.com/TIBCOSoftware/tp-helm-charts)

## Start Here

| Need | Use |
|------|-----|
| New CP + DP workshop deployment | [1.18.0 CP + DP setup](./howto/v1.18/how-to-cp-and-dp-aks-setup-guide) |
| Quick 1.18.0 commands and checks | [1.18.0 quick reference](./howto/v1.18/QUICK-REFERENCE) |
| Data Plane only with SaaS or remote Control Plane | [Data Plane only setup](./howto/how-to-dp-aks-setup-guide) |
| Pre-installation readiness | [Customer prerequisites checklist](./howto/prerequisites-checklist-for-customer) |
| Observability setup | [Data Plane observability guide](./howto/how-to-dp-aks-observability) |
| DNS records for AKS ingress | [Azure DNS guide](./howto/how-to-add-dns-records-aks-azure) |

## Release Matrix

| Version | Status | Highlights | Setup | Release Notes |
|---------|--------|------------|-------|---------------|
| 1.18.0 | Current | Gateway API, namespace-level RBAC, Console-managed email, Alert Audit Trail, Developer Hub self-service flows | [Setup](./howto/v1.18/how-to-cp-and-dp-aks-setup-guide) | [Notes](./releases/v1.18.0) |
| 1.17.0 | Previous | Webhook alerts, OpenSearch observability, BW6 lifecycle management, custom Fluentbit, BW5 Hawk REST API | [Setup](./howto/v1.17/how-to-cp-and-dp-aks-setup-guide) | [Notes](./releases/v1.17.0) |
| 1.16.0 | Previous | License management, BW6 AI Plugin 6.0.0 preview, enhanced BW5 monitoring, Flogo init/sidecar support | [Setup](./howto/v1.16/how-to-cp-and-dp-aks-setup-guide) | [Notes](./releases/v1.16.0) |
| 1.15.0 | Previous | Simplified DNS, network policy updates, capability updates | [Setup](./howto/v1.15/how-to-cp-and-dp-aks-setup-guide) | [Notes](./releases/v1.15.0) |
| 1.14.0 | Legacy | Archived baseline workshop guides | [Setup](./howto/v1.14/how-to-cp-and-dp-aks-setup-guide) | [Notes](./releases/v1.14.0) |

## Upgrade Paths

| From | To | Guide |
|------|----|-------|
| 1.17.0 | 1.18.0 | [Upgrade path](./releases/v1.18.0#upgrade-path-from-v1170) |
| 1.16.0 | 1.17.0 | [Upgrade path](./releases/v1.17.0#upgrade-path-from-v1160) |
| 1.15.0 | 1.16.0 | [Upgrade path](./releases/v1.16.0#upgrade-path-from-v1150) |
| 1.14.0 | 1.15.0 | [Upgrade path](./releases/v1.15.0#upgrade-path) |

## Deployment Scenarios

| Scenario | Description | Primary Guide |
|----------|-------------|---------------|
| CP + DP on one AKS cluster | Complete workshop or evaluation environment with Control Plane and Data Plane in the same AKS cluster | [1.18.0 CP + DP setup](./howto/v1.18/how-to-cp-and-dp-aks-setup-guide) |
| AKS Data Plane with remote CP | Customer or regional AKS Data Plane connected to SaaS or another remote Control Plane | [Data Plane only setup](./howto/how-to-dp-aks-setup-guide) |
| Observability | Prometheus, Elasticsearch/OpenSearch-related logging, Grafana, and monitoring setup | [Observability guide](./howto/how-to-dp-aks-observability) |
| Enterprise network planning | Firewall, proxy, registry, Helm repository, and external endpoint planning | [AKS firewall requirements](./docs/firewall-requirements-aks) |

## Documentation Index

### Current Release

- [1.18.0 setup overlay](./howto/v1.18/how-to-cp-and-dp-aks-setup-guide)
- [1.18.0 quick reference](./howto/v1.18/QUICK-REFERENCE)
- [1.18.0 release notes](./releases/v1.18.0)
- [1.18.0 documentation summary](./howto/v1.18/DOCUMENTATION-SUMMARY)

### Shared How-To Guides

- [Shared CP + DP baseline guide](./howto/how-to-cp-and-dp-aks-setup-guide)
- [Data Plane only setup](./howto/how-to-dp-aks-setup-guide)
- [Data Plane observability](./howto/how-to-dp-aks-observability)
- [Azure DNS records for AKS ingress](./howto/how-to-add-dns-records-aks-azure)
- [BW6 driver supplements](./howto/how-to-upload-bw6-driver-supplements)
- [Customer prerequisites checklist](./howto/prerequisites-checklist-for-customer)

### Planning and Network References

- [AKS firewall requirements](./docs/firewall-requirements-aks)
- [EKS firewall requirements](./docs/firewall-requirements-eks)
- [Connectivity test script README](./scripts/README-connectivity-test)

### Version Archives

- [v1.17 docs](./howto/v1.17/)
- [v1.16 docs](./howto/v1.16/)
- [v1.15 docs](./howto/v1.15/)
- [v1.14 docs](./howto/v1.14/)

## Minimum Requirements

| Area | Requirement |
|------|-------------|
| Azure | Subscription with permission to create or manage AKS, DNS, storage, and network resources |
| AKS | Kubernetes 1.32+ recommended for current workshop material |
| Control Plane nodes | 3+ worker nodes, Standard_D8s_v3 or larger for workshop CP + DP environments |
| Data Plane nodes | 2+ worker nodes, size based on runtime workload |
| Tools | Azure CLI 2.50.0+, kubectl, Helm 3.17.0+, openssl, jq |
| Storage | Azure Disk and Azure Files storage classes |
| Network | DNS, TLS certificates, ingress controller, and outbound access to required TIBCO/Azure endpoints |
| Registry | Access to the TIBCO container registry supplied for your entitlement/region |

Review the [Customer prerequisites checklist](./howto/prerequisites-checklist-for-customer) before installation.

## Repository Map

```text
workshop-tp-aks/
├── README.md
├── docs/                    # firewall and comparison references
├── howto/                   # setup and operational guides
│   ├── v1.14/               # archived version guides
│   ├── v1.15/
│   ├── v1.16/
│   ├── v1.17/
│   └── v1.18/               # current release overlays
├── releases/                # release notes by version
└── scripts/                 # environment, install, and connectivity helpers
```

## Official Resources

- [TIBCO Platform Control Plane 1.18.0 documentation](https://docs.tibco.com/pub/platform-cp/1.18.0/doc/html/Default.htm)
- [TIBCO Platform Control Plane 1.17.0 documentation](https://docs.tibco.com/pub/platform-cp/1.17.0/doc/html/Default.htm)
- [TIBCO tp-helm-charts repository](https://github.com/TIBCOSoftware/tp-helm-charts)
- [AKS workshop in tp-helm-charts](https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/docs/workshop/aks)
- [Azure Kubernetes Service documentation](https://learn.microsoft.com/en-us/azure/aks/)

## Support

For workshop issues, start with the relevant release notes and troubleshooting sections in the setup guides. For production deployments, work with TIBCO Support, TIBCO SI Partners, or your TIBCO Account Technical Specialist and follow the official TIBCO Platform documentation.

## License

This project is licensed under the MIT License. See [LICENSE](./LICENSE) for details.

---

**Maintained by:** TIBCO-BNL Team<br>
**Last updated:** June 11, 2026