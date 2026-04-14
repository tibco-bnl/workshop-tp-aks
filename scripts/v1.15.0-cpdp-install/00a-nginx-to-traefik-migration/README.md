# NGINX to Traefik Migration Scripts

**Purpose:** Complete toolkit for migrating from NGINX Ingress Controller to Traefik on Kubernetes/AKS

This directory contains battle-tested scripts and documentation for migrating ingress controllers with **zero downtime** using a blue-green deployment strategy. These scripts were successfully used to migrate a production cluster with 13 ingresses.

## Migration History (dp1-aks-aauk-kul cluster)

- **Migration Date:** March 18, 2026
- **Ingresses Migrated:** 13/13 (100%)
- **Previous Controller:** NGINX Ingress
- **Current Controller:** Traefik v3.6.10 (Chart 39.0.5)
- **LoadBalancer IP:** 20.54.225.126
- **DNS:** `*.dp1.atsnl-emea.azure.dataplanes.pro` → 20.54.225.126
- **Result:** ✅ Zero downtime, all applications operational

## How to Use These Scripts

### Prerequisites
1. Active Kubernetes/AKS cluster with NGINX Ingress Controller
2. kubectl configured with cluster access
3. Helm 3.x installed
4. external-dns (optional but recommended)
5. cert-manager (optional but recommended for TLS)

### Migration Steps

1. **Initial Setup**
   - Update environment variables in `../00-environment-v1.15.sh`
   - Review current ingress setup: `kubectl get ingress -A`

2. **Install Traefik (Blue-Green)**
   ```bash
   ./01b-migrate-nginx-to-traefik.sh
   ```
   - Installs Traefik on a new LoadBalancer IP
   - Both NGINX and Traefik run simultaneously
   - No disruption to existing traffic

3. **Fix External-DNS (if applicable)**
   ```bash
   ../01d-fix-external-dns.sh
   ```
   - Updates external-dns to watch both controllers
   - Fixes DNS zone configuration
   - Enables annotation-based filtering

4. **Migrate Ingresses Namespace-by-Namespace**
   
   **Option A: Manual (Recommended)**
   ```bash
   # Migrate one namespace at a time
   ./01f-migrate-namespace.sh
   # Follow prompts to select namespace
   ```
   
   **Option B: Batch Migration**
   ```bash
   # Migrate all ingresses at once
   ./quick-migrate-all.sh
   ```

5. **Check Migration Status**
   ```bash
   ./migration-status.sh
   ```
   - Shows progress percentage
   - Verifies DNS resolution
   - Detects old resources

6. **Finalize Migration**
   ```bash
   ./01c-finalize-traefik-migration.sh
   ```
   - Removes NGINX Ingress Controller
   - Attempts to reclaim original IP (optional)
   - Updates environment configuration

7. **Enable Traefik Dashboard (Optional)**
   ```bash
   ./01e-enable-traefik-dashboard.sh
   ```

8. **Cleanup Old Resources (Optional)**
   ```bash
   ./cleanup-old-dp.sh
   ```
   - Removes old TIBCO DP resources
   - Only if applicable to your cluster

## Archived Scripts

### Migration Execution Scripts
- `01b-migrate-nginx-to-traefik.sh` - Installs Traefik alongside NGINX (blue-green deployment)
- `01c-finalize-traefik-migration.sh` - Removes NGINX and finalizes migration
- `01f-migrate-namespace.sh` - Namespace-by-namespace migration tool
- `quick-migrate-all.sh` - Batch migration script

### Configuration & Utility Scripts
- `01d-enable-traefik-dashboard.sh` - Enables Traefik Web UI (older version)
- `01e-enable-traefik-dashboard.sh` - Enables Traefik Web UI (updated version)
- `migration-status.sh` - Migration progress checker
- `cleanup-old-dp.sh` - Removes old TIBCO DP resources (tibco-dp-d31hm0jnpmmc73b2qfeg)

### Documentation
- `MIGRATION-SUMMARY.md` - Comprehensive migration documentation (15 KB)
  - Blue-green migration strategy
  - Traefik v39 schema breaking changes
  - Phase-by-phase plan
  - Troubleshooting and rollback procedures
- `TRAEFIK-MIGRATION.md` - Additional migration notes (8.2 KB)

## Migrated Namespaces

| Namespace | Ingresses | Status |
|-----------|-----------|--------|
| elastic-system | 3 (kibana, elastic, apm) | ✅ Complete |
| prometheus-system | 1 (grafana) | ✅ Complete |
| ai | 8 (documentstore, ftlserver, vectorstore, etc.) | ✅ Complete |
| bpm | 1 (bpm-enterprise) | ✅ Complete |

## Key Achievements

1. **Zero Downtime:** Blue-green migration strategy
2. **DNS Automation:** external-dns managing wildcard DNS
3. **TLS Certificates:** Seamless cert-manager integration
4. **Traefik v39 Compatibility:** Fixed breaking schema changes from v33
5. **External-DNS Fix:** Corrected DNS zone and annotation filters

## Backups

All migration backups are consolidated in:
```
../backups/nginx-to-traefik-migration/
```

Contains 10 backup directories with ingress configurations, NGINX values, and migration checkpoints.

## Important Notes

### Traefik v39 Schema Changes
If using Traefik chart v39+, be aware of breaking changes from v33:
- `ports.web.redirectTo` removed (use `additionalArguments` for HTTP→HTTPS redirect)
- `ports.websecure.tls` structure changed
- `ingressClass.fallbackApiVersion` deprecated
- `accessLog` top-level moved to `logs.access`
- `logs.access.filters.statusCodes` not supported

See `MIGRATION-SUMMARY.md` for detailed schema fixes.

### DNS Management
- external-dns should use `--annotation-filter` instead of `--ingress-class`
- Verify correct DNS zone configuration
- Allow 1-2 minutes for DNS propagation after ingress changes

### Zero Downtime Strategy
- Blue-green deployment: Install Traefik before removing NGINX
- Test each namespace migration before proceeding
- Keep backups of all ingress configurations
- Rollback capability: Backups stored in `../backups/nginx-to-traefik-migration/`

## Why This Directory Exists

These scripts are maintained as a **reusable migration toolkit** because:
- NGINX to Traefik migration is a common requirement
- Zero-downtime migration requires careful orchestration
- Traefik v39 schema changes need specific handling
- Battle-tested scripts reduce migration risk
- Can be adapted for any cluster needing similar migration

## Cluster-Specific History (dp1-aks-aauk-kul)

The migration was completed on March 18, 2026 for the dp1-aks-aauk-kul cluster:
- **Result:** ✅ 100% successful, zero downtime
- **Ingresses Migrated:** 13 (elastic-system: 3, prometheus-system: 1, ai: 8, bpm: 1)
- **NGINX Status:** Fully removed
- **Traefik Status:** Active and operational
- **DNS:** Managed by external-dns, all records updated automatically

## For Future Migrations

When using these scripts for a new cluster:
1. Update `../00-environment-v1.15.sh` with your cluster details
2. Review `MIGRATION-SUMMARY.md` for complete documentation
3. Test migration on a development cluster first
4. Follow the step-by-step process above
5. Monitor `migration-status.sh` output throughout

## Support & Documentation

- **Complete Guide:** `MIGRATION-SUMMARY.md` (15 KB, comprehensive)
- **Additional Notes:** `TRAEFIK-MIGRATION.md` (8.2 KB)
- **Backups Location:** `../backups/nginx-to-traefik-migration/`
- **Questions:** Review documentation or check backup configurations

---

**Last Updated:** March 18, 2026  
**Tested On:** Azure Kubernetes Service (AKS) v1.32.6  
**Traefik Version:** v3.6.10 (Helm Chart 39.0.5)
