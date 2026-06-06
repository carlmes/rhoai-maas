# App-team workloads GitOps repo (example layout)

Copy this directory into a separate Git repository owned by the application team.
Platform engineers wire the repo URL into workload Argo CD Application templates
via `${ARGO_WORKLOADS_GIT_URL}` when rendering Applications.

## Layout

```
maas-workloads-gitops/
└── clusters/{cluster}/
    └── values/
        ├── llmisvc/values.yaml
        └── maas-subscriptions/values.yaml
```

## Model name contract

Model keys in `llmisvc/values.yaml` (`models:`) must match names referenced in
`maas-subscriptions/values.yaml` (`modelRefs`, `subscriptions`, `authPolicies`).

## Clusters in this example

- `example.cluster.opentlc.com` — full simulated free/premium model set
- `cluster-6bmxk.6bmxk.sandbox5237.opentlc.com` — llmisvc models; subscriptions use chart defaults
