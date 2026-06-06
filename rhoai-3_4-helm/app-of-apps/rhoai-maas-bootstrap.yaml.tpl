---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: rhoai-maas-bootstrap
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: rhoai-platform
  destination:
    name: in-cluster
    namespace: ${ARGOCD_NAMESPACE}
  source:
    path: rhoai-3_4-helm/applications/clusters/${ARGO_CLUSTER_DIR}/bootstrap
    repoURL: ${ARGO_GIT_URL}
    targetRevision: ${ARGO_GIT_REVISION}
    directory:
      recurse: false
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
