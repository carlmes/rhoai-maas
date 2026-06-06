---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: rhoai-platform
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "0"
spec:
  project: rhoai-platform
  destination:
    name: in-cluster
    namespace: ${ARGOCD_NAMESPACE}
  source:
    path: rhoai-3_4-helm/applications/clusters/${ARGO_CLUSTER_DIR}/platform
    repoURL: ${ARGO_GIT_URL}
    targetRevision: ${ARGO_GIT_REVISION}
    directory:
      recurse: false
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
