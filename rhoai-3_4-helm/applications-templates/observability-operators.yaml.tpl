---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: observability-operators
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  destination:
    name: in-cluster
    namespace: openshift-operators
  source:
    path: rhoai-3_4-helm/charts/observability-operators
    repoURL: ${ARGO_GIT_URL}
    targetRevision: ${ARGO_GIT_REVISION}
    helm:
      valueFiles: []
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
