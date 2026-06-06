---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: maas-workloads
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "10"
spec:
  project: maas-workloads
  destination:
    name: in-cluster
    namespace: ${ARGOCD_NAMESPACE}
  source:
    path: rhoai-3_4-helm/applications/clusters/${ARGO_CLUSTER_DIR}/workloads
    repoURL: ${ARGO_GIT_URL}
    targetRevision: ${ARGO_GIT_REVISION}
    directory:
      recurse: false
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
