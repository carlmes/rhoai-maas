---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: llmisvc
  annotations:
    argocd.argoproj.io/sync-wave: "7"
spec:
  destination:
    name: in-cluster
    namespace: ai-models
  source:
    path: rhoai-3_4-helm/charts/llmisvc
    repoURL: ${ARGO_GIT_URL}
    targetRevision: ${ARGO_GIT_REVISION}
    helm:
      valueFiles: []
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
