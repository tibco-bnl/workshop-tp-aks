# TIBCO Platform v1.16.0 Quick Reference Guide

**Cluster**: dp1-aks-aauk-kul | **Namespace**: cp1-ns | **Status**: ✅ Production

---

## Quick Access URLs

| Service | URL | Credentials |
|---------|-----|-------------|
| **Admin Console** | https://admin.dp1.atsnl-emea.azure.dataplanes.pro | admin@tibco.com / *see secret* |
| **Subscription (ai)** | https://ai.dp1.atsnl-emea.azure.dataplanes.pro | *subscription-specific* |
| **MailDev UI** | https://mail.dp1.atsnl-emea.azure.dataplanes.pro | *no auth* |

---

## Essential Commands

### Get Admin Password
```bash
kubectl get secret tp-cp-web-server -n cp1-ns -o jsonpath='{.data.TSC_ADMIN_PASSWORD}' | base64 -d && echo
```

### Check All Pods
```bash
kubectl get pods -n cp1-ns
```

### View Helm Releases
```bash
helm list -n cp1-ns
```

### Check Ingress Routes
```bash
kubectl get ingress -n cp1-ns
```

### View Logs (Control Plane Core)
```bash
kubectl logs -n cp1-ns -l app=tp-cp-infra --tail=100
```

### View Router Logs
```bash
kubectl logs -n cp1-ns -l app=cp-router --tail=100
```

### Check Database Connectivity
```bash
kubectl run psql-test -n cp1-ns --rm -it --image=postgres:15 -- \
  psql -h postgresql.tibco-ext.svc.cluster.local -U postgres -d postgres
```

---

## Helm Charts Installed

| Chart | Version | Release Name |
|-------|---------|--------------|
| tibco-cp-base | 1.16.0 | tibco-cp-base |
| tibco-cp-bw | 1.16.0 | tibco-cp-bw |
| tibco-cp-flogo | 1.16.0 | tibco-cp-flogo |
| tibco-cp-devhub | 1.16.0 | tibco-cp-devhub |
| tibco-cp-hawk | 1.16.6 | tibco-cp-hawk |
| tibco-cp-messaging | 1.15.31 | tibco-cp-messaging |

---

## Configuration Quick Reference

### Environment File
```bash
source scripts/v1.16.0-cpdp-install/aks-env-variables-dp1.sh
```

### Key Variables
```bash
TP_VERSION=1.16.0
CP_INSTANCE_ID=cp1
CP_NAMESPACE=cp1-ns
TP_BASE_DNS_DOMAIN=dp1.atsnl-emea.azure.dataplanes.pro
CP_MY_DNS_DOMAIN=admin.dp1.atsnl-emea.azure.dataplanes.pro
INGRESS_CONTROLLER=traefik
INGRESS_LOAD_BALANCER_IP=40.114.164.16
```

> **Note**: The `ai.dp1...` domain is a subscription with `hostPrefix: ai`, not a platform AI services endpoint.
```

### Container Registry
```
Registry: csgprdusw2reposaas.jfrog.io
Repository: tibco-platform-docker-dev
Username: tibco-platform-devqa
```

### Database
```
Host: postgresql.tibco-ext.svc.cluster.local
Port: 5432
Database: postgres
Username: postgres
```

### Storage
```
Class: azure-files-sc
Size: 10Gi
Access Mode: ReadWriteMany
```

---

## DNS Records

| Record | Type | Value |
|--------|------|-------|
| admin.dp1.atsnl-emea.azure.dataplanes.pro | A | 40.114.164.16 |
| ai.dp1.atsnl-emea.azure.dataplanes.pro | A | 40.114.164.16 |
| *.dp1.atsnl-emea.azure.dataplanes.pro | A | 40.114.164.16 |

---

## Common Troubleshooting

### Pod Not Starting
```bash
# Check events
kubectl describe pod <pod-name> -n cp1-ns

# Check logs
kubectl logs <pod-name> -n cp1-ns

# Check previous logs (if crashed)
kubectl logs <pod-name> -n cp1-ns --previous
```

### Ingress Not Accessible
```bash
# Verify DNS
nslookup admin.dp1.atsnl-emea.azure.dataplanes.pro

# Check Traefik
kubectl get pods -n ingress-system
kubectl logs -n ingress-system -l app.kubernetes.io/name=traefik
```

### Database Connection Issues
```bash
# Check secret
kubectl get secret cp-db-secret -n cp1-ns -o yaml

# Test connection
kubectl run psql-test -n cp1-ns --rm -it --image=postgres:15 -- \
  psql -h postgresql.tibco-ext.svc.cluster.local -U postgres
```

### Certificate Issues
```bash
# Check cert-manager pods
kubectl get pods -n cert-manager

# Check certificate status
kubectl get certificate -n cp1-ns

# Describe certificate
kubectl describe certificate <cert-name> -n cp1-ns
```

---

## Important Files

| File | Location |
|------|----------|
| Environment Variables | `scripts/v1.16.0-cpdp-install/aks-env-variables-dp1.sh` |
| Control Plane Values | `scripts/v1.16.0-cpdp-install/values/cp1-values.yaml` |
| Installation Guide | `scripts/v1.16.0-cpdp-install/README.md` |
| Release Notes | `releases/v1.16.0.md` |
| Setup Guide | `howto/how-to-cp-and-dp-aks-setup-guide.md` |

---

## Maintenance Tasks

### Backup Database
```bash
kubectl exec -n tibco-ext postgresql-0 -- \
  pg_dumpall -U postgres > backup-$(date +%Y%m%d).sql
```

### View Control Plane Status
```bash
kubectl get all -n cp1-ns
```

### Restart a Component
```bash
# Example: Restart router
kubectl rollout restart deployment/cp-router -n cp1-ns
```

### Scale a Deployment
```bash
# Example: Scale router to 2 replicas
kubectl scale deployment/cp-router -n cp1-ns --replicas=2
```

---

## New in v1.16.0

✅ **License Management**: View license details and expiration notifications (90/30/7 days)  
✅ **BW6 AI Plugin 6.0.0**: RAG (Retrieval-Augmented Generation) capabilities (Preview)  
✅ **BW5 Enhancements**: Historical logs, audit history, metrics charts with CPU/Memory  
✅ **Flogo Init/Sidecar**: Support for init and sidecar containers in values.yaml  
✅ **Developer Hub URL**: Update Developer Hub URL through UI  
✅ **Hybrid Connectivity**: Improved cloud-edge integration  

---

## Support Resources

- **Documentation**: [workshop-tp-aks repository](/README.md)
- **Release Notes**: [v1.16.0 Release Notes](/releases/v1.16.0.md)
- **Installation Guide**: [v1.16.0 Setup](/scripts/v1.16.0-cpdp-install/README.md)
- **TIBCO Docs**: https://docs.tibco.com/

---

**Last Updated**: April 10, 2026  
**Version**: 1.16.0
