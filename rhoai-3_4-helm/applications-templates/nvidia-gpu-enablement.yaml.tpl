---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: nvidia-gpu-enablement
  annotations:
    argocd.argoproj.io/sync-wave: "2"
spec:
  destination:
    name: in-cluster
    namespace: openshift-nfd
  source:
    path: rhoai-3_4-helm/charts/nvidia-gpu-enablement
    repoURL: ${ARGO_GIT_URL}
    targetRevision: ${ARGO_GIT_REVISION}
    helm:
      valueFiles: []
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
