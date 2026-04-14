#!/usr/bin/env bash

################################################################################
# Drop All CP1 Databases for Fresh Start
# 
# Purpose: Remove all cp1_* databases that may have incorrect schema from 
#          previous deployments with unsupported parameters
#
# Usage: ./04a-cleanup-databases.sh
################################################################################

set -e

# PostgreSQL connection details (in tibco-ext namespace)
export PG_HOST="postgresql.tibco-ext.svc.cluster.local"
export PG_PORT="5432"
export PG_USER="postgres"
export PG_PASSWORD="postgres"
export PG_DATABASE="postgres"

echo "========================================="
echo "Drop CP1 Databases for Fresh Start"
echo "========================================="

# List current databases
echo ""
echo "Current databases:"
kubectl run psql-list-dbs --rm -i --restart=Never --image=postgres:16 -- \
  psql "postgresql://${PG_USER}:${PG_PASSWORD}@${PG_HOST}:${PG_PORT}/${PG_DATABASE}" \
  -c "\l" | grep cp1_ || echo "No cp1_* databases found"

echo ""
read -p "⚠️  This will DELETE all cp1_* databases. Continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted."
  exit 0
fi

# Drop all cp1_* databases
echo ""
echo "Dropping databases..."

DATABASES=(
  "cp1_defaultidpdb"
  "cp1_monitoringdb"
  "cp1_penginedb"
  "cp1_tctadataserver"
  "cp1_tctadomainserver"
  "cp1_tscidmdb"
  "cp1_tscorchdb"
  "cp1_tscschedulerdb"
  "cp1_tscutdb"
)

for DB in "${DATABASES[@]}"; do
  echo "Dropping database: $DB"
  kubectl run psql-drop-$DB --rm -i --restart=Never --image=postgres:16 -- \
    psql "postgresql://${PG_USER}:${PG_PASSWORD}@${PG_HOST}:${PG_PORT}/${PG_DATABASE}" \
    -c "DROP DATABASE IF EXISTS $DB;" || true
done

echo ""
echo "✅ All cp1_* databases dropped"
echo ""
echo "Next steps:"
echo "1. Deploy CP with corrected values: ./05-deploy-cp-base.sh"
echo "2. Retrieve auto-generated password: ./06-get-admin-password.sh"
echo "3. Login to admin console: https://admin.dp1.atsnl-emea.azure.dataplanes.pro"
