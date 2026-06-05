---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: openshift-ai
  finalizers:
    - resources-finalizer.argocd.argoproj.io
  annotations:
    argocd.argoproj.io/sync-wave: "4"
spec:
  destination:
    name: in-cluster
    namespace: redhat-ods-operator
  source:
    path: rhoai-3_4-helm/charts/openshift-ai
    repoURL: ${ARGO_GIT_URL}
    targetRevision: ${ARGO_GIT_REVISION}
    helm:
      valueFiles: []
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
