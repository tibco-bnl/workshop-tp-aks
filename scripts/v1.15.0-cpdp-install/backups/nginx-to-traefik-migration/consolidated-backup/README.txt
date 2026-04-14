NGINX to Traefik Migration - Consolidated Backup
================================================

Migration Date: March 18, 2026
Cluster: dp1-aks-aauk-kul
Result: ✅ 100% successful (13/13 ingresses migrated)

Files in this backup:
---------------------

1. all-ingress-resources.yaml (18 KB)
   - Complete snapshot of all 13 ingresses BEFORE migration
   - Captured: March 18, 2026 14:22:37
   - Namespaces: elastic-system, prometheus-system, ai, bpm

2. helm-releases.yaml (3.3 KB)
   - All Helm releases at time of migration
   - Includes: NGINX ingress, external-dns, cert-manager, etc.

3. ingress-services.yaml (3.2 KB)
   - LoadBalancer and ingress-related services
   - Shows NGINX service with IP 128.251.247.140

4. elastic-system-before.yaml (4.0 KB)
   - Backup of elastic-system namespace ingresses before migration
   - 3 ingresses: kibana, elastic, apm-server

5. prometheus-system-before.yaml (1.3 KB)
   - Backup of prometheus-system namespace ingress before migration
   - 1 ingress: grafana

6. nginx-values.yaml (1.1 KB)
   - Final NGINX Helm values before removal
   - Captured: March 18, 2026 15:00:35

Migration Summary:
------------------
- Previous: NGINX Ingress (IP: 128.251.247.140)
- Current: Traefik v3.6.10 (IP: 20.54.225.126)
- Ingresses migrated: 13 (elastic-system: 3, prometheus-system: 1, ai: 8, bpm: 1)
- Downtime: Zero (blue-green deployment)
- NGINX status: Fully removed
- Rollback: Possible using these backup files

Notes:
------
- This is a consolidated backup from 10 original backup directories
- Original backups taken between 14:15 - 15:00 on March 18, 2026
- All configurations preserved for potential rollback or reference
- To restore: kubectl apply -f <backup-file>.yaml
