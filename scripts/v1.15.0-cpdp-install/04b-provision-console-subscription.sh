#!/bin/bash
# Provision Platform Console Subscription

set -e

echo "Provisioning Platform Console subscription..."

kubectl run curl-provision -n cp1-ns --image=curlimages/curl:latest --rm -i --restart=Never -- \
  curl -X POST \
  -u "admin@tibco.com:Tibco123!" \
  -H "Content-Type: application/json" \
  http://tp-cp-orchestrator.cp1-ns.svc.cluster.local:7833/v1/subscriptions \
  --data-binary @- <<'JSON'
{
  "subscriptionId": "platform-console",
  "name": "Platform Console",
  "description": "Platform Console Subscription",
  "hostPrefix": "test",
  "baseURL": "https://admin.dp1.atsnl-emea.azure.dataplanes.pro",
  "product": {
    "name": "tibco-platform-console",
    "version": "1.15.0"
  }
}
JSON

echo ""
echo "Subscription provisioned. Try logging in at:"
echo "  URL: https://admin.dp1.atsnl-emea.azure.dataplanes.pro"
echo "  Email: admin@tibco.com"
echo "  Password: Tibco123!"
