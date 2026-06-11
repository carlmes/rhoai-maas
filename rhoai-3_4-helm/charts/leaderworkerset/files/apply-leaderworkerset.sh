#!/bin/bash
set -euo pipefail

MANIFEST="/config/leaderworkerset.yaml"

echo "Waiting for LeaderWorkerSetOperator API..."
until oc apply -f "${MANIFEST}" >/dev/null 2>&1; do
  sleep 10
done

echo "LeaderWorkerSetOperator applied"
