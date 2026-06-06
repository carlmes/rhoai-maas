---
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: maas-subscriptions
  annotations:
    argocd.argoproj.io/sync-wave: "8"
spec:
  project: maas-workloads
  destination:
    name: in-cluster
    namespace: models-as-a-service
  sources:
    - repoURL: ${ARGO_GIT_URL}
      targetRevision: ${ARGO_GIT_REVISION}
      path: rhoai-3_4-helm/charts/maas-subscriptions
      helm:
        valueFiles:
          - $workloads/clusters/${ARGO_CLUSTER_DIR}/values/maas-subscriptions/values.yaml
    - repoURL: ${ARGO_WORKLOADS_GIT_URL}
      targetRevision: ${ARGO_WORKLOADS_GIT_REVISION}
      ref: workloads
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
