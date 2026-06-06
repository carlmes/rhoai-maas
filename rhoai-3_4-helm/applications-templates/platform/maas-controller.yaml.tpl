---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: maas-controller
  annotations:
    argocd.argoproj.io/sync-wave: "6"
spec:
  project: rhoai-platform
  destination:
    name: in-cluster
    namespace: openshift-ingress
  source:
    path: rhoai-3_4-helm/charts/maas-controller
    repoURL: ${ARGO_GIT_URL}
    targetRevision: ${ARGO_GIT_REVISION}
    helm:
      valueFiles:
        - ../../clusters/${ARGO_CLUSTER_DIR}/cluster.yaml
        - ../../clusters/${ARGO_CLUSTER_DIR}/platform/values/maas-controller/values.yaml
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
