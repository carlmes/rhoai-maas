#!/usr/bin/env bash
# Render Argo CD Application manifests from templates for a cluster.
#
# Usage:
#   ./scripts/render-applications.sh \
#     --cluster example.cluster.opentlc.com \
#     --platform-repo https://github.com/org/rhoai-maas.git \
#     --platform-revision main \
#     --workloads-repo https://github.com/org/maas-workloads-gitops.git \
#     --workloads-revision main \
#     --argocd-namespace openshift-gitops
#
# Outputs:
#   applications/clusters/{cluster}/platform/
#   applications/clusters/{cluster}/workloads/
#   applications/clusters/{cluster}/bootstrap/
#   argocd/projects/rendered/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

ARGO_CLUSTER_DIR=""
ARGO_GIT_URL=""
ARGO_GIT_REVISION="main"
ARGO_WORKLOADS_GIT_URL=""
ARGO_WORKLOADS_GIT_REVISION="main"
ARGOCD_NAMESPACE="openshift-gitops"

usage() {
  sed -n '2,12p' "$0"
  exit 1
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --cluster) ARGO_CLUSTER_DIR="$2"; shift 2 ;;
    --platform-repo) ARGO_GIT_URL="$2"; shift 2 ;;
    --platform-revision) ARGO_GIT_REVISION="$2"; shift 2 ;;
    --workloads-repo) ARGO_WORKLOADS_GIT_URL="$2"; shift 2 ;;
    --workloads-revision) ARGO_WORKLOADS_GIT_REVISION="$2"; shift 2 ;;
    --argocd-namespace) ARGOCD_NAMESPACE="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown option: $1" >&2; usage ;;
  esac
done

if [[ -z "${ARGO_CLUSTER_DIR}" || -z "${ARGO_GIT_URL}" || -z "${ARGO_WORKLOADS_GIT_URL}" ]]; then
  echo "Error: --cluster, --platform-repo, and --workloads-repo are required." >&2
  usage
fi

if [[ ! -d "${HELM_ROOT}/clusters/${ARGO_CLUSTER_DIR}" ]]; then
  echo "Error: cluster directory not found: clusters/${ARGO_CLUSTER_DIR}" >&2
  exit 1
fi

render_template() {
  local src="$1"
  local dest="$2"
  sed \
    -e "s|\${ARGO_CLUSTER_DIR}|${ARGO_CLUSTER_DIR}|g" \
    -e "s|\${ARGO_GIT_URL}|${ARGO_GIT_URL}|g" \
    -e "s|\${ARGO_GIT_REVISION}|${ARGO_GIT_REVISION}|g" \
    -e "s|\${ARGO_WORKLOADS_GIT_URL}|${ARGO_WORKLOADS_GIT_URL}|g" \
    -e "s|\${ARGO_WORKLOADS_GIT_REVISION}|${ARGO_WORKLOADS_GIT_REVISION}|g" \
    -e "s|\${ARGOCD_NAMESPACE}|${ARGOCD_NAMESPACE}|g" \
    "${src}" > "${dest}"
}

PLATFORM_OUT="${HELM_ROOT}/applications/clusters/${ARGO_CLUSTER_DIR}/platform"
WORKLOADS_OUT="${HELM_ROOT}/applications/clusters/${ARGO_CLUSTER_DIR}/workloads"
BOOTSTRAP_OUT="${HELM_ROOT}/applications/clusters/${ARGO_CLUSTER_DIR}/bootstrap"
PROJECTS_OUT="${HELM_ROOT}/argocd/projects/rendered"

mkdir -p "${PLATFORM_OUT}" "${WORKLOADS_OUT}" "${BOOTSTRAP_OUT}" "${PROJECTS_OUT}"

for tpl in "${HELM_ROOT}"/applications-templates/platform/*.yaml.tpl; do
  base="$(basename "${tpl}" .tpl)"
  render_template "${tpl}" "${PLATFORM_OUT}/${base}"
done

for tpl in "${HELM_ROOT}"/applications-templates/workloads/*.yaml.tpl; do
  base="$(basename "${tpl}" .tpl)"
  render_template "${tpl}" "${WORKLOADS_OUT}/${base}"
done

render_template "${HELM_ROOT}/app-of-apps/rhoai-platform.yaml.tpl" \
  "${BOOTSTRAP_OUT}/rhoai-platform.yaml"
render_template "${HELM_ROOT}/app-of-apps/maas-workloads.yaml.tpl" \
  "${BOOTSTRAP_OUT}/maas-workloads.yaml"

render_template "${HELM_ROOT}/argocd/projects/rhoai-platform.yaml.tpl" \
  "${PROJECTS_OUT}/rhoai-platform.yaml"
render_template "${HELM_ROOT}/argocd/projects/maas-workloads.yaml.tpl" \
  "${PROJECTS_OUT}/maas-workloads.yaml"

render_template "${HELM_ROOT}/app-of-apps/rhoai-maas-bootstrap.yaml.tpl" \
  "${HELM_ROOT}/applications/clusters/${ARGO_CLUSTER_DIR}/rhoai-maas-bootstrap.yaml"

echo "Rendered Applications for cluster: ${ARGO_CLUSTER_DIR}"
echo "  Platform child apps:  ${PLATFORM_OUT}/"
echo "  Workload child apps:  ${WORKLOADS_OUT}/"
echo "  Bootstrap apps:       ${BOOTSTRAP_OUT}/"
echo "  AppProjects:          ${PROJECTS_OUT}/"
echo "  Bootstrap root app:   applications/clusters/${ARGO_CLUSTER_DIR}/rhoai-maas-bootstrap.yaml"
echo
echo "Apply AppProjects, then create the bootstrap Application in ${ARGOCD_NAMESPACE}."
