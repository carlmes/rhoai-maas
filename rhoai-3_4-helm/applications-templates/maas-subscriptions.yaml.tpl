---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: maas-subscriptions
  annotations:
    argocd.argoproj.io/sync-wave: "8"
spec:
  destination:
    name: in-cluster
    namespace: models-as-a-service
  source:
    path: rhoai-3_4-helm/charts/maas-subscriptions
    repoURL: ${ARGO_GIT_URL}
    targetRevision: ${ARGO_GIT_REVISION}
    helm:
      valueFiles: []
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
