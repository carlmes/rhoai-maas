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
wait_for_install_plan_completion "kuadrant-system" "rhcl-operator"
wait_for_install_plan_completion "openshift-lws-operator" "leader-worker-set"
wait_for_install_plan_completion "redhat-ods-operator" "rhods-operator"
wait_for_install_plan_completion "openshift-operators" "servicemeshoperator3"

echo "Patching ClusterServiceVersion for Red Hat Connectivity Link:"
echo "   - name: ISTIO_GATEWAY_CONTROLLER_NAMES"
echo "     value: 'istio.io/gateway-controller,openshift.io/gateway-controller/v1'"
echo ""
ENV_INDEX=$(oc get ClusterServiceVersion rhcl-operator.v1.3.4 -n kuadrant-system -o json | \
  jq '.spec.install.spec.deployments[0].spec.template.spec.containers[0].env | map(.name) | index("ISTIO_GATEWAY_CONTROLLER_NAMES")')
oc patch ClusterServiceVersion rhcl-operator.v1.3.4 -n kuadrant-system --type=json -p \
  "[{\"op\":\"replace\",\"path\":\"/spec/install/spec/deployments/0/spec/template/spec/containers/0/env/${ENV_INDEX}/value\",\"value\":\"istio.io/gateway-controller,openshift.io/gateway-controller/v1\"}]"

echo "Enabling kuadrant-console-plugin in the OpenShift Console"
oc patch console.operator.openshift.io cluster --type=json -p \
  '[{"op":"add","path":"/spec/plugins/-","value":"kuadrant-console-plugin"}]'

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

echo "Annotating the authorino-authorino-authorization service with serving cert secret name"
oc patch service authorino-authorino-authorization -n kuadrant-system --type=merge -p \
  '{"metadata":{"annotations":{"service.beta.openshift.io/serving-cert-secret-name":"authorino-server-cert"}}}'

echo "Restarting kuadrant-operator-controller-manager so it picks up the new cert"
oc delete pod -n kuadrant-system -l control-plane=controller-manager --wait=false

echo "Patching Authorino CR to enable TLS with the serving cert"
oc patch authorino authorino -n kuadrant-system --type=merge -p \
  '{"spec":{"clusterWide":true,"healthz":{},"listener":{"ports":{},"tls":{"certSecretRef":{"name":"authorino-server-cert"},"enabled":true}}}}'


echo "=========================================================================="
echo " 5. overlays/05-odhdashboard"
echo " Updates the ODH Dashboard Config to enable MaaS and GenAI studio (only for v3.3?) Has to be installed after DSC"
echo ""

echo "Applying the configuration from: ${KUSTOMIZE_DIR}/overlays/05-odhdashboard"
apply_firmly ${KUSTOMIZE_DIR}/overlays/05-odhdashboard


echo "=========================================================================="
echo " 6. overlays/06-postgres"
echo " Creates MaaS Postgres instance used for API key lifecycle management."
echo ""

echo "Applying the configuration from: ${KUSTOMIZE_DIR}/overlays/06-postgres"
apply_firmly ${KUSTOMIZE_DIR}/overlays/06-postgres

echo "Waiting for Postgres deployment to be ready..."
oc rollout status deployment/postgres -n redhat-ods-applications --timeout=120s

# Create the maas-db-config secret by copying the config from the postgres-creds secret
#
# RHOAI 3.4 MaaS Doc: https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4/html/govern_llm_access_with_models-as-a-service/deploy-and-manage-models-as-a-service_maas#configure-postgresql-secret-for-maas_maas-deploy
#
echo "Creating the 'maas-db-config' secret from from postgres-creds secret..."
POSTGRES_USER=$(oc get secret postgres-creds -n redhat-ods-applications \
  -o jsonpath='{.data.POSTGRES_USER}' | base64 -d)
POSTGRES_PASSWORD=$(oc get secret postgres-creds -n redhat-ods-applications \
  -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d)
POSTGRES_DB=$(oc get secret postgres-creds -n redhat-ods-applications \
  -o jsonpath='{.data.POSTGRES_DB}' | base64 -d)
oc create secret generic maas-db-config \
  -n redhat-ods-applications \
  --from-literal=DB_CONNECTION_URL="postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres:5432/${POSTGRES_DB}?sslmode=disable" \
  --dry-run=client -o yaml | oc apply -f -
oc label secret maas-db-config -n redhat-ods-applications "app=maas-api" "purpose=poc" --overwrite

# Rollout restart — restarts the maas-api deployment to pick up the new arguments
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
echo " 10. overlays/10-observability-dashboard-rhoai"
echo " Creates Observability stack for testing"
echo ""

echo "Applying the configuration from: ${KUSTOMIZE_DIR}/overlays/10-observability-dashboard-rhoai"
apply_firmly ${KUSTOMIZE_DIR}/overlays/10-observability-dashboard-rhoai

# Reference: https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.4/html/govern_llm_access_with_models-as-a-service/deploy-and-manage-models-as-a-service_maas#enable-maas-telemetry_maas-deploy
echo "Enabling Telemetry for Models-as-a-Service"
oc patch tenants.maas.opendatahub.io default-tenant -n models-as-a-service \
  --type merge \
  -p '{
    "spec": {
      "telemetry": {
        "enabled": true,
        "metrics": {
          "captureOrganization": true,
          "captureUser": false,
          "captureGroup": false,
          "captureModelUsage": true
        }
      }
    }
  }'


echo "=========================================================================="
echo " 11. Restarting rhoai-dashboard pods to pick up new ODH Dashboard config"
echo ""

oc rollout restart deployment/rhods-dashboard -n redhat-ods-applications
oc rollout status deployment/rhods-dashboard -n redhat-ods-applications --timeout=120s
