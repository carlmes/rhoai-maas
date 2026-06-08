#!/bin/bash
set -euo pipefail

NAMESPACE="${POSTGRES_NAMESPACE:?POSTGRES_NAMESPACE required}"
POSTGRES_SECRET="${POSTGRES_SECRET:?POSTGRES_SECRET required}"
MAAS_DB_SECRET="${MAAS_DB_SECRET:?MAAS_DB_SECRET required}"
POSTGRES_SERVICE="${POSTGRES_SERVICE:?POSTGRES_SERVICE required}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"

echo "Waiting for postgres deployment in ${NAMESPACE}..."
oc rollout status deployment/postgres -n "${NAMESPACE}" --timeout=300s

POSTGRES_USER=$(oc get secret "${POSTGRES_SECRET}" -n "${NAMESPACE}" \
  -o jsonpath='{.data.POSTGRES_USER}' | base64 -d)
POSTGRES_PASSWORD=$(oc get secret "${POSTGRES_SECRET}" -n "${NAMESPACE}" \
  -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d)
POSTGRES_DB=$(oc get secret "${POSTGRES_SECRET}" -n "${NAMESPACE}" \
  -o jsonpath='{.data.POSTGRES_DB}' | base64 -d)

DB_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_SERVICE}:${POSTGRES_PORT}/${POSTGRES_DB}?sslmode=disable"

oc create secret generic "${MAAS_DB_SECRET}" \
  -n "${NAMESPACE}" \
  --from-literal=DB_CONNECTION_URL="${DB_URL}" \
  --dry-run=client -o yaml | oc apply -f -

oc label secret "${MAAS_DB_SECRET}" -n "${NAMESPACE}" \
  "app=maas-api" "purpose=poc" --overwrite

echo "Created/updated secret ${MAAS_DB_SECRET}"

if oc get deployment maas-api -n "${NAMESPACE}" >/dev/null 2>&1; then
  echo "Restarting maas-api deployment..."
  oc rollout restart deployment/maas-api -n "${NAMESPACE}"
  oc rollout status deployment/maas-api -n "${NAMESPACE}" --timeout=300s
else
  echo "maas-api deployment not found yet; secret is ready for when it appears"
fi
