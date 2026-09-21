# TIBCO Platform on Azure Kubernetes Service (AKS) Workshop

Guides and supporting resources for deploying TIBCO Platform Control Plane and Data Plane on Azure Kubernetes Service.

> **Current release:** [v1.20.0](./releases/v1.20.0) | **TIBCO Platform CP:** 1.20.0<br>
> **Upgrade path:** [1.18.0 to 1.19.0](./releases/v1.19.0#upgrade-path-from-v1180), then [1.19.0 to 1.20.0](./releases/v1.20.0#upgrade-path-from-v1190)<br>
> **Official charts:** [TIBCO tp-helm-charts](https://github.com/TIBCOSoftware/tp-helm-charts)

## Start Here

| Need | Use |
|------|-----|
| New CP + DP workshop deployment | [1.20.0 CP + DP setup](./howto/v1.20/how-to-cp-and-dp-aks-setup-guide) |
| Quick 1.20.0 commands and checks | [1.20.0 quick reference](./howto/v1.20/QUICK-REFERENCE) |
| Upgrading from 1.18.0 | [1.19.0 overlay](./howto/v1.19/how-to-cp-and-dp-aks-setup-guide) first, then the 1.20.0 setup |
| Data Plane only with SaaS or remote Control Plane | [Data Plane only setup](./howto/how-to-dp-aks-setup-guide) |
| Pre-installation readiness | [Customer prerequisites checklist](./howto/prerequisites-checklist-for-customer) |
| Observability setup | [Data Plane observability guide](./howto/how-to-dp-aks-observability) |
| DNS records for AKS ingress | [Azure DNS guide](./howto/how-to-add-dns-records-aks-azure) |

## Release Matrix

| Version | Status | Highlights | Setup | Release Notes |
|---------|--------|------------|-------|---------------|
| 1.20.0 | Current | Control Plane rollback, OTLP custom headers, Flogo build Jobs, Developer Hub MCP Catalog, MCP Hub (Preview, TIBCO Operated CP), new `disabledInfraCapabilities` value | [Setup](./howto/v1.20/how-to-cp-and-dp-aks-setup-guide) | [Notes](./releases/v1.20.0) |
| 1.19.0 | Previous (mandatory hop from 1.18.0) | TESSA (Preview), ActiveSpaces capability, Infra MCP Server, PromQL cards, Jaeger v2, `createDeprecatedPolicies` removed, Gateway API hybrid-proxy route fixed | [Setup](./howto/v1.19/how-to-cp-and-dp-aks-setup-guide) | [Notes](./releases/v1.19.0) |
| 1.18.0 | Previous | Gateway API, namespace-level RBAC, Console-managed email, Alert Audit Trail, Developer Hub self-service flows | [Setup](./howto/v1.18/how-to-cp-and-dp-aks-setup-guide) | [Notes](./releases/v1.18.0) |
| 1.17.0 | Previous | Webhook alerts, OpenSearch observability, BW6 lifecycle management, custom Fluentbit, BW5 Hawk REST API | [Setup](./howto/v1.17/how-to-cp-and-dp-aks-setup-guide) | [Notes](./releases/v1.17.0) |
| 1.16.0 | Previous | License management, BW6 AI Plugin 6.0.0 preview, enhanced BW5 monitoring, Flogo init/sidecar support | [Setup](./howto/v1.16/how-to-cp-and-dp-aks-setup-guide) | [Notes](./releases/v1.16.0) |
| 1.15.0 | Previous | Simplified DNS, network policy updates, capability updates | [Setup](./howto/v1.15/how-to-cp-and-dp-aks-setup-guide) | [Notes](./releases/v1.15.0) |
| 1.14.0 | Legacy | Archived baseline workshop guides | [Setup](./howto/v1.14/how-to-cp-and-dp-aks-setup-guide) | [Notes](./releases/v1.14.0) |

## Upgrade Paths

| From | To | Guide |
|------|----|-------|
| 1.19.0 | 1.20.0 | [Upgrade path](./releases/v1.20.0#upgrade-path-from-v1190) |
| 1.18.0 | 1.19.0 | [Upgrade path](./releases/v1.19.0#upgrade-path-from-v1180) |
| 1.17.0 | 1.18.0 | [Upgrade path](./releases/v1.18.0#upgrade-path-from-v1170) |
| 1.16.0 | 1.17.0 | [Upgrade path](./releases/v1.17.0#upgrade-path-from-v1160) |
| 1.15.0 | 1.16.0 | [Upgrade path](./releases/v1.16.0#upgrade-path-from-v1150) |
| 1.14.0 | 1.15.0 | [Upgrade path](./releases/v1.15.0#upgrade-path) |

The official upgrade assistants in `tp-helm-charts/scripts/<version>/upgrade.sh` move one minor version at a time; use `scripts/MASTER-UPGRADE-README.md` for multi-hop upgrades. 1.20.0 adds Control Plane rollback via `helm rollback`.

## Deployment Scenarios

| Scenario | Description | Primary Guide |
|----------|-------------|---------------|
| Architecture and topology planning | Choose CP/DP topology, DTAP cluster organization, subscription strategy, and deployment flavor | [Topology options](./howto/topology-options) |
| CP + DP on one AKS cluster | Complete workshop or evaluation environment with Control Plane and Data Plane in the same AKS cluster | [1.20.0 CP + DP setup](./howto/v1.20/how-to-cp-and-dp-aks-setup-guide) |
| AKS Data Plane with remote CP | Customer or regional AKS Data Plane connected to SaaS or another remote Control Plane | [Data Plane only setup](./howto/how-to-dp-aks-setup-guide) |
| Observability | Prometheus, Elasticsearch/OpenSearch-related logging, Grafana, and monitoring setup | [Observability guide](./howto/how-to-dp-aks-observability) |
| Enterprise network planning | Firewall, proxy, registry, Helm repository, and external endpoint planning | [AKS firewall requirements](./docs/firewall-requirements-aks) |

## Documentation Index

### Current Release

- [1.20.0 setup overlay](./howto/v1.20/how-to-cp-and-dp-aks-setup-guide)
- [1.20.0 quick reference](./howto/v1.20/QUICK-REFERENCE)
- [1.20.0 release notes](./releases/v1.20.0)
- [1.20.0 documentation summary](./howto/v1.20/DOCUMENTATION-SUMMARY)

### Upgrade Hop: 1.19.0

- [1.19.0 setup overlay](./howto/v1.19/how-to-cp-and-dp-aks-setup-guide)
- [1.19.0 quick reference](./howto/v1.19/QUICK-REFERENCE)
- [1.19.0 release notes](./releases/v1.19.0)
- [1.19.0 documentation summary](./howto/v1.19/DOCUMENTATION-SUMMARY)

### Shared How-To Guides

- [Topology options](./howto/topology-options) — CP/DP topology patterns, DTAP organization, subscription strategies, API Gateway, and deployment flavors
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

### Image Synchronization

- [How to push TIBCO Platform images to a custom container registry](./howto/how-to-sync-images) — official `sync-images.sh` script, `docker buildx imagetools`, `skopeo`, air-gapped staging, ACR setup, and image integrity verification

### Version Archives

- [v1.18 docs](./howto/v1.18/)
- [v1.17 docs](./howto/v1.17/)
- [v1.16 docs](./howto/v1.16/)
- [v1.15 docs](./howto/v1.15/)
- [v1.14 docs](./howto/v1.14/)

## Minimum Requirements

| Area | Requirement |
|------|-------------|
| Azure | Subscription with permission to create or manage AKS, DNS, storage, and network resources |
| AKS | Kubernetes 1.33 recommended (highest version certified by TIBCO for the Control Plane cluster in 1.20.0); the upstream tp-helm-charts AKS workshop uses 1.35 |
| Control Plane nodes | 3+ worker nodes, Standard_D8s_v3 or larger for workshop CP + DP environments |
| Data Plane nodes | 2+ worker nodes, size based on runtime workload |
| Tools | Azure CLI 2.88.0 (upstream tested), kubectl v1.34.3, Helm 3.17.0+ (3.18.0 upstream), openssl, jq 1.8+, yq 4.45.4+ |
| Storage | Azure Disk and Azure Files storage classes (use Azure Disk for Developer Hub PostgreSQL, see PLTDX-1343) |
| Network | DNS, TLS certificates, Traefik ingress controller or a supported Gateway API controller, and outbound access to required TIBCO/Azure endpoints |
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
│   ├── v1.18/
│   ├── v1.19/               # upgrade hop from 1.18
│   └── v1.20/               # current release overlays
├── releases/                # release notes by version (v1.14.0 ... v1.20.0)
└── scripts/                 # environment, install, and connectivity helpers
```

## Official Resources

- [TIBCO Platform Control Plane 1.20.0 documentation](https://docs.tibco.com/pub/platform-cp/1.20.0/doc/html/Default.htm)
- [TIBCO Platform Control Plane 1.19.0 documentation](https://docs.tibco.com/pub/platform-cp/1.19.0/doc/html/Default.htm)
- [TIBCO Platform Control Plane 1.18.0 documentation](https://docs.tibco.com/pub/platform-cp/1.18.0/doc/html/Default.htm)
- [TIBCO tp-helm-charts repository](https://github.com/TIBCOSoftware/tp-helm-charts)
- [AKS workshop in tp-helm-charts](https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/docs/workshop/aks)
- [Official upgrade scripts (1.19.0, 1.20.0)](https://github.com/TIBCOSoftware/tp-helm-charts/tree/main/scripts)
- [Azure Kubernetes Service documentation](https://learn.microsoft.com/en-us/azure/aks/)

## Support

For workshop issues, start with the relevant release notes and troubleshooting sections in the setup guides. For production deployments, work with TIBCO Support, TIBCO SI Partners, or your TIBCO Account Technical Specialist and follow the official TIBCO Platform documentation.

## License

This project is licensed under the MIT License. See [LICENSE](./LICENSE) for details.

---

**Maintained by:** TIBCO-BNL Team<br>
**Last updated:** September 21, 2026
