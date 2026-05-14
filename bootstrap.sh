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




#| 2 | `overlays/02-nfd-nvidia-lws-instances` | Creates NFD instance and NVIDIA ClusterPolicy (GPU nodes) and Lead Worker Set Instance |
#| 3 | `overlays/03-gateway` | Creates Gatewayclass and Maas Gateway !! UPDATE HOST NAME !! |
#| 4 | `overlays/04-rhoai` | Creates DataScienceCluster and Authorinio NetworkPolicy |
#| 5 | `overlays/05-odhdashboard` | Updates teh ODH Dashboard Config to enable MaaS and GenAI studio (only for v3.3?) Has to be installed after DSC |
#| 6 | `overlays/06-postgres` | Creates Postgres instance for token storage WIP |
#| 7 | `overlays/07-maas-controller` | ~~Creates Maas-controller deployment,~~ Policies, RBAC ~~and CRDS~~ (needed for v3.4) |
#| 8 | `overlays/08-simulated-models` | Creates dummy models for testing |


# 2. Apply lws-operator-cr

# 3. Install rhcl
# Make sure csv for rhcl has: - name: ISTIO_GATEWAY_CONTROLLER_NAMES
#     value: 'istio.io/gateway-controller,openshift.io/gateway-controller/v1'

# 4. Check tls cert for Gateway/maas-default-gateway.yaml in openshift-ingress and apply

# 5. Apply Kuadrant custom resource in rh-connectivity-link


# 6. Install rhoai.... Make sure odhdashboard config is updated and dsc is updated. Llamastack needs to be enabled too

# 7. Deploy Postgres with secrets

# 8. Deploy auth-policies

# 9. Configuring TLS backend for Authorino and MaaS API..

# 10. Restart rollout of deployment Maas-api and authorinio

# 11. Delete kuadrant operator controller manager in kuadrant system if llm doesn’t come up because of authoring…..check authpolicy - maas-api-auth-policy (it said to restart kuadrant operator controller manager pod) …. This helps when requesting a token and returning null

