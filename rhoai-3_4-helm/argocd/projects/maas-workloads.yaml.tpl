---
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: maas-workloads
  namespace: ${ARGOCD_NAMESPACE}
spec:
  description: Application team — MaaS models and subscriptions (waves 7–8)
  sourceRepos:
    - ${ARGO_GIT_URL}
    - ${ARGO_WORKLOADS_GIT_URL}
  destinations:
    - namespace: ai-models
      server: https://kubernetes.default.svc
    - namespace: models-as-a-service
      server: https://kubernetes.default.svc
    - namespace: ${ARGOCD_NAMESPACE}
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: serving.kserve.io
      kind: LLMInferenceService
    - group: maas.opendatahub.io
      kind: "*"
    - group: kuadrant.io
      kind: TokenRateLimitPolicy
    - group: kuadrant.io
      kind: AuthPolicy
  namespaceResourceWhitelist:
    - group: serving.kserve.io
      kind: "*"
    - group: maas.opendatahub.io
      kind: "*"
    - group: kuadrant.io
      kind: "*"
    - group: ""
      kind: Secret
    - group: ""
      kind: ConfigMap
    - group: ""
      kind: Service
    - group: ""
      kind: ServiceAccount
    - group: ""
      kind: PersistentVolumeClaim
    - group: ""
      kind: Namespace
    - group: batch
      kind: Job
    - group: apps
      kind: Deployment
    - group: rbac.authorization.k8s.io
      kind: Role
    - group: rbac.authorization.k8s.io
      kind: RoleBinding
