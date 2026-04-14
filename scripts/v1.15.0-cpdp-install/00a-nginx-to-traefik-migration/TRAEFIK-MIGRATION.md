# NGINX to Traefik Migration Guide

## Overview

This guide walks you through migrating from NGINX Ingress Controller to Traefik for TIBCO Platform v1.15.0. Traefik provides better integration with cloud-native patterns and v1.15.0 features.

## Why Migrate to Traefik?

- ✅ Native support for modern protocols (HTTP/3, gRPC)
- ✅ Better Kubernetes integration with CRDs
- ✅ Built-in metrics for Prometheus
- ✅ Automatic service discovery
- ✅ Simpler configuration
- ✅ Better performance for microservices
- ✅ Official TIBCO Platform recommendation for v1.15.0

## Migration Strategy

We use a **blue-green deployment** approach:
1. Install Traefik alongside NGINX
2. Verify Traefik has the correct IP
3. Migrate ingress resources one namespace at a time
4. Test each migration
5. Remove NGINX once everything is verified

## Prerequisites

- NGINX ingress currently running
- LoadBalancer IP preserved: `128.251.247.140`
- DNS configured: `*.dp1.atsnl-emea.azure.dataplanes.pro`
- Backup of existing configuration

## Migration Steps

### Step 1: Install Traefik (Blue-Green)

```bash
cd /Users/kul/git/tib/workshop-tp-aks/scripts/v1.15.0-cpdp-install
source 00-environment-v1.15.sh

# Install Traefik alongside NGINX
./01b-migrate-nginx-to-traefik.sh
```

**What this does:**
- Installs Traefik in `ingress-system` namespace
- Preserves the LoadBalancer IP `128.251.247.140`
- Configures DNS annotation `*.dp1.atsnl-emea.azure.dataplanes.pro`
- Adds Azure health probes
- Applies IP whitelisting (if configured)
- Creates ingress migration helper script

**Expected output:**
```
✅ Traefik LoadBalancer IP: 128.251.247.140
```

### Step 2: Verify Traefik Installation

```bash
# Check Traefik pods
kubectl get pods -n ingress-system -l app.kubernetes.io/name=traefik

# Check Traefik service
kubectl get svc traefik -n ingress-system

# View Traefik logs
kubectl logs -n ingress-system -l app.kubernetes.io/name=traefik --tail=50
```

### Step 3: Migrate Ingress Resources

The migration script creates a helper at `/tmp/migrate-ingress-resources.sh` to update ingress resources.

#### Migrate Elasticsearch/Kibana

```bash
# Check current ingress
kubectl get ingress -n elastic-system

# Migrate to Traefik
/tmp/migrate-ingress-resources.sh elastic-system

# Verify
kubectl get ingress kibana -n elastic-system -o yaml | grep -A2 "spec:"
```

#### Migrate Prometheus/Grafana

```bash
# Migrate to Traefik
/tmp/migrate-ingress-resources.sh prometheus-system

# Verify
kubectl get ingress -n prometheus-system
```

### Step 4: Test Traefik Ingress

```bash
# Test Kibana
curl -k -I https://kibana.dp1.atsnl-emea.azure.dataplanes.pro
# Expected: HTTP/2 200 or 302

# Test Grafana
curl -k -I https://grafana.dp1.atsnl-emea.azure.dataplanes.pro
# Expected: HTTP/2 200 or 302

# Test from browser
open https://kibana.dp1.atsnl-emea.azure.dataplanes.pro
open https://grafana.dp1.atsnl-emea.azure.dataplanes.pro
```

### Step 5: Finalize Migration (Remove NGINX)

Once you've verified Traefik is working correctly:

```bash
# Final migration step - removes NGINX
./01c-finalize-traefik-migration.sh
```

**What this does:**
- Verifies all ingress resources migrated
- Tests Traefik ingress
- Backs up NGINX configuration
- Removes NGINX Helm releases
- Sets Traefik as default ingress class

### Step 6: Update Environment Configuration

```bash
# Edit environment file
vi 00-environment-v1.15.sh

# Change this line:
export INGRESS_CONTROLLER="traefik"

# Reload environment
source 00-environment-v1.15.sh
```

## Verification Checklist

- [ ] Traefik pods running (2 replicas)
- [ ] LoadBalancer IP matches: `128.251.247.140`
- [ ] DNS resolves correctly: `dig +short kibana.dp1.atsnl-emea.azure.dataplanes.pro`
- [ ] Kibana accessible via browser
- [ ] Grafana accessible via browser
- [ ] No ingress resources using `nginx` class
- [ ] Traefik set as default ingress class
- [ ] NGINX Helm releases removed

```bash
# Quick verification script
kubectl get pods -n ingress-system
kubectl get svc traefik -n ingress-system
kubectl get ingressclass
kubectl get ingress -A -o jsonpath='{range .items[*]}{.metadata.namespace}{"\t"}{.metadata.name}{"\t"}{.spec.ingressClassName}{"\n"}{end}' | column -t
```

## Troubleshooting

### Issue: Traefik gets different IP

**Symptom:** Traefik LoadBalancer IP is not `128.251.247.140`

**Solution:**
```bash
# Option 1: Update Traefik service to use specific IP
kubectl patch svc traefik -n ingress-system -p '{"spec":{"loadBalancerIP":"128.251.247.140"}}'

# Option 2: Update DNS to point to new IP
az network dns record-set a update \
  --resource-group kul-atsbnl \
  --zone-name dp1.atsnl-emea.azure.dataplanes.pro \
  --name "*" \
  --set aRecords[0].ipv4Address=<NEW_IP>
```

### Issue: Ingress resources not working

**Symptom:** 404 or connection refused errors

**Solution:**
```bash
# Check Traefik routes
kubectl get ingressroute -A

# Check Traefik configuration
kubectl logs -n ingress-system -l app.kubernetes.io/name=traefik --tail=100 | grep -i error

# Verify ingress class
kubectl get ingress <name> -n <namespace> -o yaml | grep ingressClassName
```

### Issue: TLS certificate errors

**Symptom:** Certificate warnings in browser

**Solution:**
```bash
# Traefik generates default certificates
# For production, configure cert-manager with Let's Encrypt

# Check TLS secret
kubectl get secret -n <namespace> <tls-secret-name>

# View certificate details
kubectl get secret <tls-secret-name> -n <namespace> -o jsonpath='{.data.tls\.crt}' | base64 -d | openssl x509 -noout -text
```

### Issue: NGINX can't be removed

**Symptom:** Helm uninstall fails

**Solution:**
```bash
# Force remove with cleanup
helm uninstall dp-config-aks-nginx -n ingress-system --no-hooks

# Clean up remaining resources
kubectl delete deployment,svc -n ingress-system -l app.kubernetes.io/name=nginx
```

## Rollback Procedure

If you need to rollback to NGINX:

```bash
# 1. Set Traefik as non-default
kubectl annotate ingressclass traefik ingressclass.kubernetes.io/is-default-class=false --overwrite

# 2. Restore NGINX from backup
helm install dp-config-aks-nginx tibco-platform/dp-config-aks \
  --namespace ingress-system \
  --values ${BACKUP_DIR}/nginx-helm-values.yaml

# 3. Migrate ingress resources back to nginx
kubectl get ingress -A -o json | \
  jq '.items[] | select(.spec.ingressClassName=="traefik") | .spec.ingressClassName = "nginx"' | \
  jq 'del(.metadata.uid, .metadata.resourceVersion, .metadata.creationTimestamp, .metadata.generation, .metadata.managedFields, .status)' | \
  kubectl apply -f -

# 4. Remove Traefik
helm uninstall traefik -n ingress-system
```

## Comparison: NGINX vs Traefik

| Feature | NGINX | Traefik |
|---------|-------|---------|
| Configuration | Annotations | CRDs + Annotations |
| Metrics | Separate exporter | Built-in |
| Protocol Support | HTTP/1.1, HTTP/2 | HTTP/1.1, HTTP/2, HTTP/3 |
| Service Discovery | Manual | Automatic |
| Dashboard | Separate | Built-in |
| gRPC Support | Basic | Native |
| Weight ed routing | Limited | Native |
| Middleware | Limited | Extensive |
| TIBCO Platform v1.15.0 | Supported | Recommended |

## Performance Notes

**Traefik advantages:**
- Lower latency for API Gateway patterns
- Better connection pooling
- More efficient for microservices (1000+ services)
- Dynamic configuration updates without reload

**Resource usage:**
- Traefik: ~500MB RAM, 0.5 CPU baseline
- NGINX: ~300MB RAM, 0.3 CPU baseline

For TIBCO Platform workloads, Traefik's improved integration outweighs the slight resource increase.

## Next Steps

After completing migration:

1. **Install TIBCO Platform Control Plane:**
   ```bash
   ./04-install-controlplane.sh
   ```

2. **Install TIBCO Platform Data Plane:**
   ```bash
   ./05-install-dataplane.sh
   ```

3. **Monitor Traefik:**
   ```bash
   # View metrics in Prometheus
   # ServiceMonitor is automatically created
   
   # View access logs
   kubectl logs -n ingress-system -l app.kubernetes.io/name=traefik -f | jq .
   ```

## References

- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [TIBCO Platform v1.15.0 Guide](../../howto/v1.15/)
- [Traefik Helm Chart](https://github.com/traefik/traefik-helm-chart)
- [Migration Helper Script](./01b-migrate-nginx-to-traefik.sh)

---

**Last Updated:** March 18, 2026  
**Cluster:** dp1-aks-aauk-kul  
**NGINX Version:** 1.x (dp-config-aks)  
**Traefik Version:** 33.4.0
