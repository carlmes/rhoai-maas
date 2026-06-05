---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: rhcl
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  destination:
    name: in-cluster
    namespace: kuadrant-system
  source:
    path: rhoai-3_4-helm/charts/rhcl
    repoURL: ${ARGO_GIT_URL}
    targetRevision: ${ARGO_GIT_REVISION}
    helm:
      valueFiles: []
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
