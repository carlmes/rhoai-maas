# Moved to separate GitOps repos

The Helm/GitOps layout previously in this directory now lives in two repositories:

| Repo | Purpose |
|------|---------|
| [javo8a/rhoai-platform](https://github.com/javo8a/rhoai-platform) | Platform charts, cluster values, Argo CD Applications (waves 1–6), bootstrap |
| [javo8a/rhoai-workloads](https://github.com/javo8a/rhoai-workloads) | App-team workload values (`llmisvc`, `maas-subscriptions`) |

Local clones:

```bash
git clone git@github.com:javo8a/rhoai-platform.git
git clone git@github.com:javo8a/rhoai-workloads.git
```

See `HELM.md` in the platform repo for bootstrap and rendering instructions.
