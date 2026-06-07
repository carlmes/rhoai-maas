# RHOAI 3.4 Helm Charts

Helm-based GitOps layout for deploying RHOAI 3.4 and Models-as-a-Service (MaaS), following the pattern from [openshift-setup](https://github.com/jharmison-redhat/openshift-setup).

The existing Kustomize tree at [`rhoai-3_4/`](../rhoai-3_4/) and [`bootstrap.sh`](../bootstrap.sh) are unchanged. Use this directory for Helm/ArgoCD deployments.

## Directory Layout

```
rhoai-3_4-helm/
├── charts/                         # Shared Helm charts (platform team)
├── clusters/                       # Per-cluster platform values
│   └── example.cluster.opentlc.com/
│       ├── cluster.yaml            # Global cluster name/domain/toolsImage
│       └── platform/values/{app}/  # Platform chart overrides
├── applications-templates/
│   ├── platform/                   # Child Application templates (waves 1–6)
│   └── workloads/                  # Multi-source child templates (waves 7–8)
├── applications/clusters/{cluster}/  # Rendered Applications (generated)
│   ├── platform/
│   ├── workloads/
│   ├── bootstrap/
│   └── rhoai-maas-bootstrap.yaml
├── app-of-apps/                    # Root Application templates
├── argocd/projects/                # AppProject templates + rendered/
├── examples/maas-workloads-gitops/ # App-team values repo layout (copy to separate repo)
├── scripts/render-applications.sh  # Template renderer
└── HELM.md
```

## Ownership Split (Two Repos)

| Owner | Argo CD root app | Sync waves | Charts |
|-------|------------------|------------|--------|
| **Platform engineers** | `rhoai-platform` | 1–6 | `cert-manager`, `observability-operators`, `nvidia-gpu-enablement`, `leaderworkerset`, `rhcl`, `gateway-api`, `openshift-ai`, `maas-postgres`, `maas-controller` |
| **Application team** | `maas-workloads` | 7–8 | `llmisvc`, `maas-subscriptions` |

Platform delivers the MaaS **control plane** (operators, gateway, RHOAI, Postgres, Kuadrant policies). The application team delivers **workloads and catalog/access** (`LLMInferenceService`, `MaaSModelRef`, `MaaSAuthPolicy`, `MaaSSubscription`).

### Platform repo (this repo)

- All charts under `charts/`
- `clusters/{cluster}/cluster.yaml` and `clusters/{cluster}/platform/values/**`
- Application templates, rendered `applications/`, AppProjects, bootstrap app

### App-team repo (separate)

Copy [`examples/maas-workloads-gitops/`](examples/maas-workloads-gitops/) into a dedicated repository:

```
maas-workloads-gitops/
└── clusters/{cluster}/
    └── values/
        ├── llmisvc/values.yaml
        └── maas-subscriptions/values.yaml
```

Workload charts use Argo CD **multi-source** Applications: chart path from the platform repo, values from the app-team repo via `$workloads/...` refs.

**Model name contract:** keys in `llmisvc` `models:` must match names in `maas-subscriptions` `modelRefs`, `subscriptions`, and `authPolicies`.

## Install Order (Sync Waves)

| Wave | Chart | Owner | Description |
|------|-------|-------|-------------|
| 1 | `cert-manager` | Platform | cert-manager operator |
| 1 | `observability-operators` | Platform | Tempo, Cluster Observability, OpenTelemetry operators |
| 2 | `nvidia-gpu-enablement` | Platform | NFD + NVIDIA GPU operator and instances |
| 2 | `leaderworkerset` | Platform | Leader Worker Set operator and instance |
| 2 | `rhcl` | Platform | Red Hat Connectivity Link + Kuadrant |
| 3 | `gateway-api` | Platform | GatewayClass + maas-default-gateway |
| 4 | `openshift-ai` | Platform | RHOAI operator, DSC, dashboard, observability DSCI |
| 5 | `maas-postgres` | Platform | Postgres for MaaS API key storage |
| 6 | `maas-controller` | Platform | MaaS CRDs, RBAC, Kuadrant policies |
| 7 | `llmisvc` | App team | LLMInferenceService models |
| 8 | `maas-subscriptions` | App team | MaaSModelRef, MaaSAuthPolicy, MaaSSubscription |

## Quick Start

### 1. Configure platform values for your cluster

```bash
cp -r clusters/example.cluster.opentlc.com clusters/mycluster.mydomain.com
# Edit clusters/mycluster.mydomain.com/cluster.yaml:
#   global.cluster.name
#   global.cluster.baseDomain
#   global.toolsImage
```

### 2. Create the app-team workloads repo

```bash
cp -r examples/maas-workloads-gitops /path/to/maas-workloads-gitops
# Edit clusters/mycluster.mydomain.com/values/llmisvc/values.yaml
# Edit clusters/mycluster.mydomain.com/values/maas-subscriptions/values.yaml
```

### 3. Render Argo CD Applications

```bash
./scripts/render-applications.sh \
  --cluster mycluster.mydomain.com \
  --platform-repo https://github.com/org/rhoai-maas.git \
  --platform-revision main \
  --workloads-repo https://github.com/org/maas-workloads-gitops.git \
  --workloads-revision main \
  --argocd-namespace openshift-gitops
```

Commit the rendered files under `applications/clusters/{cluster}/` and `argocd/projects/rendered/`.

### 4. Bootstrap Argo CD (platform team)

1. Apply AppProjects from `argocd/projects/rendered/` to the GitOps namespace.
2. Create the bootstrap Application from `applications/clusters/{cluster}/rhoai-maas-bootstrap.yaml`.

The bootstrap app creates two child root Applications with sync-wave ordering:

- `rhoai-platform` at wave **0** — platform child apps (waves 1–6)
- `maas-workloads` at wave **10** — workload child apps (waves 7–8)

### 5. App-team onboarding

After platform sync is healthy (see checklist below), the application team:

1. Pushes model/subscription values to their repo.
2. Syncs the `maas-workloads` Application (automated if enabled).
3. Validates models appear in the MaaS catalog and subscriptions grant access.

### Platform readiness checklist

Before relying on workload sync, confirm:

- [ ] `maas-default-gateway` is programmed in `openshift-ingress`
- [ ] DataScienceCluster and RHOAI dashboard are ready
- [ ] `maas-controller` Kuadrant policies exist
- [ ] Postgres is running and `maas-db-config` secret was created
- [ ] GPU nodes are labeled if deploying GPU models (`nvidia.com/gpu.present=true`)

## Value Layering

### Platform charts

Charts merge values in this order (later overrides earlier):

1. `charts/{app}/values.yaml` — chart defaults
2. `clusters/{cluster}/cluster.yaml` — global cluster name/domain/toolsImage
3. `clusters/{cluster}/platform/values/{app}/values.yaml` — per-app overrides

The gateway hostname is templated from cluster globals:

```
maas.apps.{cluster.name}.{cluster.baseDomain}
```

### Disconnected clusters (optional)

For air-gapped or disconnected environments, set `disconnected.enabled: true` in `clusters/{cluster}/cluster.yaml` and update the registry/image fields for that cluster:

```yaml
disconnected:
  enabled: true
  wasmShimImage: registry.example.com/rhcl-1/wasm-shim-rhel9@sha256:...
  protectedRegistry: registry.example.com
  gatewayConfig:
    wasmInsecureRegistries: registry.example.com
    serviceType: ClusterIP  # lab only; omit on production clusters
```

This enables:

- **`rhcl`**: copies `pull-secret` to `wasm-plugin-pull-secret` and patches the operator subscription (`RELATED_IMAGE_WASMSHIM`, `PROTECTED_REGISTRY`) — bootstrap.sh step 11
- **`gateway-api`**: creates `default-gateway-config` with `WASM_INSECURE_REGISTRIES` for the gateway istio-proxy

Leave `disconnected.enabled: false` (default) on connected clusters such as OpenTLC sandboxes.

### Workload charts

1. `charts/{app}/values.yaml` — chart defaults (platform repo)
2. `clusters/{cluster}/values/{app}/values.yaml` — app-team overrides (workloads repo)

## Argo CD GitOps

### AppProjects and RBAC

| AppProject | Team | `sourceRepos` | Destinations |
|------------|------|---------------|--------------|
| `rhoai-platform` | Platform | Platform repo only | Operator and system namespaces |
| `maas-workloads` | Application | Platform + workloads repos | `ai-models`, `models-as-a-service` |

Grant platform engineers `project/rhoai-platform` permissions. Grant application teams `project/maas-workloads` only — they can sync workloads without modifying operators or gateway configuration.

Templates: [`argocd/projects/rhoai-platform.yaml.tpl`](argocd/projects/rhoai-platform.yaml.tpl), [`argocd/projects/maas-workloads.yaml.tpl`](argocd/projects/maas-workloads.yaml.tpl).

### Platform child Application (single-source)

```yaml
spec:
  project: rhoai-platform
  source:
    path: rhoai-3_4-helm/charts/gateway-api
    repoURL: https://github.com/org/rhoai-maas.git
    helm:
      valueFiles:
        - ../../clusters/example.cluster.opentlc.com/cluster.yaml
        - ../../clusters/example.cluster.opentlc.com/platform/values/gateway-api/values.yaml
```

### Workload child Application (multi-source)

```yaml
spec:
  project: maas-workloads
  sources:
    - repoURL: https://github.com/org/rhoai-maas.git
      path: rhoai-3_4-helm/charts/llmisvc
      helm:
        valueFiles:
          - $workloads/clusters/example.cluster.opentlc.com/values/llmisvc/values.yaml
    - repoURL: https://github.com/org/maas-workloads-gitops.git
      ref: workloads
```

Requires Argo CD 2.6+ / OpenShift GitOps 1.8+ for multi-source Applications.

## Manual Helm Install (phased)

For clusters without Argo CD, install in wave order:

```bash
CLUSTER=clusters/example.cluster.opentlc.com
WORKLOADS=/path/to/maas-workloads-gitops/clusters/example.cluster.opentlc.com
CHARTS=charts

# Waves 1–6 (platform)
helm upgrade --install cert-manager $CHARTS/cert-manager -n cert-manager-operator --create-namespace \
  -f $CLUSTER/cluster.yaml -f $CLUSTER/platform/values/cert-manager/values.yaml
# ... remaining platform charts ...

# Waves 7–8 (workloads)
helm upgrade --install llmisvc $CHARTS/llmisvc -n ai-models \
  -f $WORKLOADS/values/llmisvc/values.yaml
helm upgrade --install maas-subscriptions $CHARTS/maas-subscriptions -n models-as-a-service \
  -f $WORKLOADS/values/maas-subscriptions/values.yaml
```

## Bootstrap.sh Parity

All imperative steps from [`bootstrap.sh`](../bootstrap.sh) are encoded in the Helm charts:

| bootstrap.sh step | Helm chart | Implementation |
|-------------------|------------|----------------|
| RHCL CSV `ISTIO_GATEWAY_CONTROLLER_NAMES` patch | `rhcl` | Job `patch-rhcl-csv` |
| Enable `kuadrant-console-plugin` | `rhcl` | Job `enable-console-plugin` |
| Gateway hostname patch | `gateway-api` | Templated from `cluster.yaml` |
| DataScienceCluster + Authorino NetworkPolicy | `openshift-ai` | Templates |
| Authorino service serving-cert annotation | `rhcl` | `service-authorino.yaml` (SSA) |
| Authorino TLS spec | `rhcl` | `authorino.yaml` |
| Restart kuadrant-operator-controller | `rhcl` | Job `restart-kuadrant-operator` |
| OdhDashboardConfig (MaaS dashboard flags) | `openshift-ai` | `odhdashboardconfig.yaml` |
| Postgres deployment | `maas-postgres` | `postgres.yaml` |
| `maas-db-config` secret + maas-api restart | `maas-postgres` | Job `create-maas-db-config` |
| MaaS Kuadrant policies | `maas-controller` | Policy templates |
| Simulated LLM models | `llmisvc` | Multi-model templates |
| MaaS subscriptions | `maas-subscriptions` | Subscription templates |
| Observability DSCI + cluster monitoring | `openshift-ai` | DSCInitialization + ConfigMap |
| `default-tenant` telemetry | `maas-subscriptions` | `tenant-telemetry.yaml` |
| Restart `rhods-dashboard` | `openshift-ai` | Job `restart-rhods-dashboard` |
| WASM shim disconnected workaround | `rhcl` | Job `apply-wasm-shim-workaround` (optional via `disconnected.enabled`) |
| Gateway `default-gateway-config` (WASM insecure registries) | `gateway-api` | ConfigMap `default-gateway-config` (optional via `disconnected.enabled`) |

Post-install Jobs use the cluster `toolsImage` (must include `oc` and `jq`) and run as Helm post-install/post-upgrade hooks (ArgoCD sync-wave ordered).

## Chart Sources

| Chart | Source |
|-------|--------|
| `install-operators`, `cert-manager`, `nvidia-gpu-enablement`, `leaderworkerset`, `rhcl`, `gateway-api`, `openshift-ai`, `llmisvc`, `maas-subscriptions` | Adapted from [openshift-setup](https://github.com/jharmison-redhat/openshift-setup) |
| `maas-postgres`, `maas-controller`, `observability-operators` | Created from [`rhoai-3_4/`](../rhoai-3_4/) Kustomize manifests |

## Validation

Compare Helm output against Kustomize for parity:

```bash
# Gateway
helm template test charts/gateway-api \
  -f clusters/example.cluster.opentlc.com/cluster.yaml \
  -f clusters/example.cluster.opentlc.com/platform/values/gateway-api/values.yaml \
  | grep -A5 "kind: Gateway"

kustomize build ../rhoai-3_4/overlays/03-gateway | grep -A5 "kind: Gateway"
```

Update chart dependencies after cloning:

```bash
for c in rhcl leaderworkerset openshift-ai observability-operators; do
  (cd charts/$c && helm dependency update)
done
```
