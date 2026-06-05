---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: maas-postgres
  annotations:
    argocd.argoproj.io/sync-wave: "5"
spec:
  destination:
    name: in-cluster
    namespace: redhat-ods-applications
  source:
    path: rhoai-3_4-helm/charts/maas-postgres
    repoURL: ${ARGO_GIT_URL}
    targetRevision: ${ARGO_GIT_REVISION}
    helm:
      valueFiles: []
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
