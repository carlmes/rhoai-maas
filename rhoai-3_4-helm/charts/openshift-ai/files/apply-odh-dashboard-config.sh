#!/bin/bash
set -euo pipefail

MANIFEST="/config/odh-dashboard-config.yaml"

echo "Waiting for OdhDashboardConfig API..."
until oc apply -f "${MANIFEST}" >/dev/null 2>&1; do
  sleep 10
done

echo "OdhDashboardConfig applied"
