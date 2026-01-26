# Network Connectivity Test Job for TIBCO Platform on AKS

This Kubernetes Job tests connectivity to all required, recommended, and optional endpoints needed for TIBCO Platform deployment on Azure Kubernetes Service (AKS).

## Overview

The connectivity test validates access to:
- **CRITICAL endpoints**: TIBCO registries, Helm repos, Azure services (deployment will fail if these are blocked)
- **RECOMMENDED endpoints**: Microsoft Container Registry, Kubernetes, GitHub (some features may not work)
- **OPTIONAL endpoints**: Documentation sites (useful for troubleshooting)

## Prerequisites

- Access to an AKS cluster with `kubectl` configured
- Cluster must have outbound internet connectivity (or proxy configured)
- Permissions to create ConfigMaps and Jobs in the target namespace

## Quick Start

### 1. Deploy the Connectivity Test Job

```bash
# Apply the job (includes ConfigMap with test script)
kubectl apply -f scripts/connectivity-test-job.yaml

# Wait for job to complete (typically 30-60 seconds)
kubectl wait --for=condition=complete --timeout=120s job/connectivity-test
```

### 2. View the Results

```bash
# Get the test results from job logs
kubectl logs job/connectivity-test

# Alternative: Get pod name and view logs
POD_NAME=$(kubectl get pods -l job-name=connectivity-test -o jsonpath='{.items[0].metadata.name}')
kubectl logs $POD_NAME
```

### 3. Check Job Status

```bash
# Check if job completed successfully
kubectl get job connectivity-test

# Expected output for success:
# NAME                 COMPLETIONS   DURATION   AGE
# connectivity-test    1/1           45s        2m

# Check exit code
kubectl get job connectivity-test -o jsonpath='{.status.conditions[0].type}'
# Should show: Complete
```

## Understanding the Results

### Exit Codes

- **Exit Code 0**: All checks passed (CRITICAL, RECOMMENDED, OPTIONAL)
- **Exit Code 1**: CRITICAL endpoints failed - deployment will likely fail
- **Exit Code 2**: RECOMMENDED endpoints failed - deployment may proceed with limited functionality

### Report Sections

The test report includes:

1. **CRITICAL Endpoints** - Must be accessible
   - TIBCO JFrog registry (`csgprduswrepoedge.jfrog.io`)
   - TIBCO Helm charts (`tibcosoftware.github.io`)
   - Third-party Helm repos (cert-manager, Elastic ECK, Prometheus)
   - Container registries (Docker Hub, GitHub Container Registry)
   - Azure services (Resource Manager, Azure AD, CSI drivers)

2. **RECOMMENDED Endpoints** - Highly recommended
   - Microsoft Container Registry (`mcr.microsoft.com`)
   - Kubernetes (`k8s.io`, `kubernetes.io`)
   - GitHub (`github.com`)
   - Azure Blob Storage

3. **OPTIONAL Endpoints** - For documentation
   - Microsoft Learn, Prometheus.io, Elastic.co, etc.

### Sample Output

```
=========================================================================
TIBCO Platform Connectivity Test Report
Platform: Azure Kubernetes Service (AKS)
Date: Thu Jan 23 10:30:45 UTC 2026
Hostname: connectivity-test-xyz123
=========================================================================

SECTION 1: CRITICAL ENDPOINTS (Must be accessible)
=========================================================================

--- TIBCO Container Registry (CRITICAL) ---
✓ PASS https://csgprduswrepoedge.jfrog.io (HTTP 200)

--- TIBCO Helm Charts (CRITICAL) ---
✓ PASS https://tibcosoftware.github.io/tp-helm-charts (HTTP 200)
✓ PASS https://tibcosoftware.github.io/tp-helm-charts/index.yaml (HTTP 200)

...

=========================================================================
CONNECTIVITY TEST SUMMARY
=========================================================================

CRITICAL Endpoints:
  Total: 18
  Passed: 18
  Failed: 0

RECOMMENDED Endpoints:
  Total: 7
  Passed: 7
  Failed: 0

OPTIONAL Endpoints:
  Total: 5
  Passed: 5
  Failed: 0

=========================================================================
OVERALL STATISTICS
=========================================================================
Total Tests: 30
Total Passed: 30
Total Failed: 0
Pass Rate: 100.00%

=========================================================================
RECOMMENDATIONS
=========================================================================
✓ All CRITICAL endpoints are accessible
✓ All RECOMMENDED endpoints are accessible

=========================================================================
NEXT STEPS
=========================================================================
1. ✓ All required connectivity checks passed
2. Proceed with TIBCO Platform deployment
3. Monitor connectivity during deployment
```

## Troubleshooting

### If CRITICAL Endpoints Fail

1. **Check firewall rules**:
   ```bash
   # Review firewall requirements document
   cat docs/firewall-requirements.md
   ```

2. **Test specific endpoint manually**:
   ```bash
   kubectl run test --image=curlimages/curl --rm -it -- \
     curl -I https://csgprduswrepoedge.jfrog.io
   ```

3. **Check proxy settings** (if using proxy):
   ```bash
   kubectl run test --image=curlimages/curl --rm -it -- env | grep -i proxy
   ```

4. **Review NSG/Azure Firewall rules**:
   - See `docs/firewall-requirements.md` Section 8 for NSG rules
   - See `docs/firewall-requirements.md` Section 9 for Azure Firewall rules

### If Job Fails to Start

```bash
# Check pod events
kubectl describe job connectivity-test

# Check pod status
kubectl get pods -l job-name=connectivity-test

# View pod logs if in error state
kubectl logs -l job-name=connectivity-test --all-containers
```

### Re-running the Test

```bash
# Delete existing job
kubectl delete job connectivity-test

# Reapply after firewall changes
kubectl apply -f scripts/connectivity-test-job.yaml

# Monitor progress
kubectl logs -f job/connectivity-test
```

## Customization

### Test Different Namespace

```bash
# Edit the YAML file or use kubectl with namespace flag
kubectl apply -f scripts/connectivity-test-job.yaml -n tibco-platform

# View logs
kubectl logs -n tibco-platform job/connectivity-test
```

### Add Custom Endpoints

Edit the ConfigMap in `connectivity-test-job.yaml` and add URLs to the test script:

```bash
# Add to CRITICAL section
for url in \
    "https://csgprduswrepoedge.jfrog.io" \
    "https://your-custom-endpoint.com"
do
    if test_url "$url" "CRITICAL"; then
        ((CRITICAL_PASS++))
    else
        ((CRITICAL_FAIL++))
        CRITICAL_FAILED+=("$url")
    fi
done
```

### Adjust Timeout

Edit the `timeout` variable in the test script (default is 5 seconds):

```bash
test_url() {
    local url=$1
    local category=$2
    local timeout=10  # Increase to 10 seconds
    ...
}
```

## Integration with CI/CD

### Use in Azure Pipelines

```yaml
- task: Kubernetes@1
  displayName: 'Run Connectivity Test'
  inputs:
    command: apply
    arguments: '-f scripts/connectivity-test-job.yaml'

- task: Kubernetes@1
  displayName: 'Wait for Test Completion'
  inputs:
    command: wait
    arguments: '--for=condition=complete --timeout=120s job/connectivity-test'

- task: Kubernetes@1
  displayName: 'Get Test Results'
  inputs:
    command: logs
    arguments: 'job/connectivity-test'
```

### Use in GitHub Actions

```yaml
- name: Run Connectivity Test
  run: |
    kubectl apply -f scripts/connectivity-test-job.yaml
    kubectl wait --for=condition=complete --timeout=120s job/connectivity-test
    kubectl logs job/connectivity-test
    
    # Fail pipeline if critical endpoints failed
    if kubectl get job connectivity-test -o jsonpath='{.status.failed}' | grep -q "1"; then
      echo "Connectivity test failed"
      exit 1
    fi
```

## Cleanup

```bash
# Delete the job (ConfigMap will remain for reuse)
kubectl delete job connectivity-test

# Delete both job and ConfigMap
kubectl delete -f scripts/connectivity-test-job.yaml
```

## Job Retention

The job is configured with `ttlSecondsAfterFinished: 86400` (24 hours), which means:
- Completed jobs are automatically cleaned up after 24 hours
- Failed jobs are also cleaned up after 24 hours
- Logs can be retrieved within this time window

To keep jobs longer, edit the YAML:

```yaml
spec:
  ttlSecondsAfterFinished: 604800  # 7 days
```

## Related Documentation

- [Firewall Requirements](../docs/firewall-requirements.md) - Complete list of required endpoints
- [Network Security Group Rules](../docs/firewall-requirements.md#8-network-security-group-nsg-rules-for-azure)
- [Azure Firewall Rules](../docs/firewall-requirements.md#9-azure-firewall-application-rules)
- [Firewall Request Template](../docs/firewall-requirements.md#15-simplified-firewall-request-template)

## Support

If connectivity tests fail:

1. Review the [firewall requirements document](../docs/firewall-requirements.md)
2. Contact your network/security team with the test results
3. Use the [firewall request template](../docs/firewall-requirements.md#sample-firewall-request-form) to request access
4. Re-run tests after firewall changes are applied
