#!/bin/bash
set -e

# Default values
TIMEOUT_SECONDS=45
KUSTOMIZE_DIR="rhoai-3_4"

# shellcheck source=/dev/null
source "$(dirname "$0")/scripts/functions.sh"
source "$(dirname "$0")/scripts/util.sh"
source "$(dirname "$0")/scripts/command_flags.sh" "$@"

# Verify CLI tooling
setup_bin
check_bin oc
check_bin kustomize
check_oc_login


echo "=========================================================================="
echo " 1. overlays/01-operators"
echo " Installs NFD, NVIDIA GPU, Connectivity Link, Leader Worker Set, and RHOAI operators via OLM"
echo ""

echo "Applying the configuration from: ${KUSTOMIZE_DIR}/overlays/01-operators"
apply_firmly ${KUSTOMIZE_DIR}/overlays/01-operators

wait_for_install_plan_completion "openshift-nfd" "nfd"
wait_for_install_plan_completion "nvidia-gpu-operator" "gpu-operator-certified"
wait_for_install_plan_completion "cert-manager-operator" "openshift-cert-manager-operator"
wait_for_install_plan_completion "rh-connectivity-link" "rhcl-operator"
wait_for_install_plan_completion "openshift-lws-operator" "leader-worker-set"
wait_for_install_plan_completion "redhat-ods-operator" "rhods-operator"

echo "Patching ClusterServiceVersion for Red Hat Connectivity Link:"
echo "   - name: ISTIO_GATEWAY_CONTROLLER_NAMES"
echo "     value: 'istio.io/gateway-controller,openshift.io/gateway-controller/v1'"
echo ""
ENV_INDEX=$(oc get ClusterServiceVersion rhcl-operator.v1.3.3 -n rh-connectivity-link -o json | \
  jq '.spec.install.spec.deployments[0].spec.template.spec.containers[0].env | map(.name) | index("ISTIO_GATEWAY_CONTROLLER_NAMES")')
oc patch ClusterServiceVersion rhcl-operator.v1.3.3 -n rh-connectivity-link --type=json -p \
  "[{\"op\":\"replace\",\"path\":\"/spec/install/spec/deployments/0/spec/template/spec/containers/0/env/${ENV_INDEX}/value\",\"value\":\"istio.io/gateway-controller,openshift.io/gateway-controller/v1\"}]"

echo "=========================================================================="
echo " 2. overlays/02-nfd-nvidia-lws-instances"
echo " Create NFD instance and NVIDIA ClusterPolicy (GPU nodes) and Lead Worker Set Instance"
echo ""

echo "Applying the configuration from: ${KUSTOMIZE_DIR}/overlays/02-nfd-nvidia-lws-instances"
apply_firmly ${KUSTOMIZE_DIR}/overlays/02-nfd-nvidia-lws-instances


echo "=========================================================================="
echo " 3. overlays/03-gateway"
echo " Creates Gatewayclass and Maas Gateway !! UPDATE HOST NAME !!"
echo ""

echo "Applying the configuration from: ${KUSTOMIZE_DIR}/overlays/03-gateway"
apply_firmly ${KUSTOMIZE_DIR}/overlays/03-gateway

echo "Update the hostname in maas-default-gateway"
GATEWAY_HOSTNAME=$(oc get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}' | sed 's/^apps\./maas.apps./')
echo "Patching Gateway hostname to: ${GATEWAY_HOSTNAME}"
oc patch gateway maas-default-gateway -n openshift-ingress --type=json -p \
  "[{\"op\":\"replace\",\"path\":\"/spec/listeners/0/hostname\",\"value\":\"${GATEWAY_HOSTNAME}\"},
    {\"op\":\"replace\",\"path\":\"/spec/listeners/1/hostname\",\"value\":\"${GATEWAY_HOSTNAME}\"}]"


echo "=========================================================================="
echo " 4. overlays/04-rhoai"
echo " Creates DataScienceCluster and Authorinio NetworkPolicy"
echo ""

echo "Applying the configuration from: ${KUSTOMIZE_DIR}/overlays/04-rhoai"
apply_firmly ${KUSTOMIZE_DIR}/overlays/04-rhoai

echo "Annotating authorino-authorinio-authorization service with serving cert secret name"
oc patch service authorino-authorinio-authorization -n rh-connectivity-link --type=merge -p \
  '{"metadata":{"annotations":{"service.beta.openshift.io/serving-cert-secret-name":"authorino-server-cert"}}}'

echo "Restarting kuadrant-operator-controller-manager so it picks up the new cert"
oc delete pod -n rh-connectivity-link -l control-plane=controller-manager --wait=false

echo "Patching Authorino CR to enable TLS with the serving cert"
oc patch authorino authorino -n rh-connectivity-link --type=merge -p \
  '{"spec":{"clusterWide":true,"healthz":{},"listener":{"ports":{},"tls":{"certSecretRef":{"name":"authorino-server-cert"},"enabled":true}}}}'


echo "=========================================================================="
echo " 5. overlays/05-odhdashboard"
echo " Updates the ODH Dashboard Config to enable MaaS and GenAI studio (only for v3.3?) Has to be installed after DSC"
echo ""

echo "Applying the configuration from: ${KUSTOMIZE_DIR}/overlays/05-odhdashboard"
apply_firmly ${KUSTOMIZE_DIR}/overlays/05-odhdashboard


echo "=========================================================================="
echo " 6. overlays/06-postgres"
echo " Creates Postgres instance for token storage WIP"
echo ""

echo "Applying the configuration from: ${KUSTOMIZE_DIR}/overlays/06-postgres"
apply_firmly ${KUSTOMIZE_DIR}/overlays/06-postgres

echo "Waiting for Postgres deployment to be ready..."
oc rollout status deployment/postgres -n redhat-ods-applications --timeout=120s

# Secret bridge — postgres.yaml creates a secret named maas-db-config, but the maas-api 
# deployment template (from maas-api.yaml) references database-config. The script reads 
# the connection URL out of maas-db-config and uses --dry-run=client | oc apply (idempotent) 
#to create database-config with the same value.
echo "Creating 'database-config' secret for maas-api from postgres connection URL"
DB_CONNECTION_URL=$(oc get secret maas-db-config -n redhat-ods-applications \
  -o jsonpath='{.data.DB_CONNECTION_URL}' | base64 -d)
oc create secret generic database-config \
  -n redhat-ods-applications \
  --from-literal=DB_CONNECTION_URL="${DB_CONNECTION_URL}" \
  --dry-run=client -o yaml | oc apply -f -

# --storage=external patch — the maas-api.yaml reference file shows the deployment must 
# pass --storage=external so the API uses Postgres instead of in-memory storage. The || true 
# makes it a no-op if the arg is already set by RHOAI.
echo "Ensuring maas-api uses external storage and rolling out restart"
oc patch deployment maas-api -n redhat-ods-applications --type=json -p \
  '[{"op":"add","path":"/spec/template/spec/containers/0/args","value":["--storage=external"]}]' \
  2>/dev/null || true

# rollout restart — this restarts the deployment to pick up the new argument without downtime
oc rollout restart deployment/maas-api -n redhat-ods-applications
oc rollout status deployment/maas-api -n redhat-ods-applications --timeout=120s


echo "=========================================================================="
echo " 7. overlays/07-maas-controller"
echo " Creates Maas-controller deployment, Policies, RBAC and CRDS"
echo ""

echo "Applying the configuration from: ${KUSTOMIZE_DIR}/overlays/07-maas-controller"
apply_firmly ${KUSTOMIZE_DIR}/overlays/07-maas-controller

echo "=========================================================================="
echo " 8. overlays/08-simulated-models"
echo " Creates dummy models for testing"
echo ""

echo "Applying the configuration from: ${KUSTOMIZE_DIR}/overlays/08-simulated-models"
apply_firmly ${KUSTOMIZE_DIR}/overlays/08-simulated-models


echo "=========================================================================="
echo " 9. overlays/09-maas-subscriptions"
echo " Creates MaaS subscriptions for testing"
echo ""

echo "Applying the configuration from: ${KUSTOMIZE_DIR}/overlays/09-maas-subscriptions"
apply_firmly ${KUSTOMIZE_DIR}/overlays/09-maas-subscriptions


echo "=========================================================================="
echo " 10. overlays/10-observability"
echo " Creates Observability stack for testing"
echo ""

echo "Applying the configuration from: ${KUSTOMIZE_DIR}/overlays/10-observability"
apply_firmly ${KUSTOMIZE_DIR}/overlays/10-observability

