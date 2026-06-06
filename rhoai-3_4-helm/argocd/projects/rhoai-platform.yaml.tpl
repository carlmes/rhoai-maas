---
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: rhoai-platform
  namespace: ${ARGOCD_NAMESPACE}
spec:
  description: Platform engineers — RHOAI cluster bootstrap (waves 1–6)
  sourceRepos:
    - ${ARGO_GIT_URL}
  destinations:
    - namespace: cert-manager-operator
      server: https://kubernetes.default.svc
    - namespace: openshift-operators
      server: https://kubernetes.default.svc
    - namespace: openshift-nfd
      server: https://kubernetes.default.svc
    - namespace: nvidia-gpu-operator
      server: https://kubernetes.default.svc
    - namespace: openshift-lws-operator
      server: https://kubernetes.default.svc
    - namespace: kuadrant-system
      server: https://kubernetes.default.svc
    - namespace: openshift-ingress
      server: https://kubernetes.default.svc
    - namespace: redhat-ods-operator
      server: https://kubernetes.default.svc
    - namespace: redhat-ods-applications
      server: https://kubernetes.default.svc
    - namespace: redhat-ods-monitoring
      server: https://kubernetes.default.svc
    - namespace: ${ARGOCD_NAMESPACE}
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: "*"
      kind: "*"
  namespaceResourceWhitelist:
    - group: "*"
      kind: "*"
