# RHOAI 3.4 Helm Charts

Helm-based layout for deploying RHOAI 3.4 and Models-as-a-Service (MaaS), following the pattern from [openshift-setup](https://github.com/jharmison-redhat/openshift-setup).

The existing Kustomize tree at [`rhoai-3_4/`](../rhoai-3_4/) and [`bootstrap.sh`](../bootstrap.sh) are unchanged. Use this directory for direct Helm deployments.

## Directory Layout

```
rhoai-3_4-helm/
├── charts/                         # Reusable Helm charts
├── clusters/                       # Per-cluster values
│   └── example.cluster.opentlc.com/
│       ├── cluster.yaml            # Global cluster name/domain/toolsImage
│       ├── platform/values/{app}/  # Platform chart overrides (waves 1–6)
│       └── values/{app}/           # Workload chart overrides (waves 7–8)
└── HELM.md
```

**Model name contract:** keys in `llmisvc` `models:` must match names in `maas-subscriptions` `modelRefs`, `subscriptions`, and `authPolicies`.

## Install Order

| Wave | Chart | Description |
|------|-------|-------------|
| 1 | `cert-manager` | cert-manager operator |
| 1 | `observability-operators` | Tempo, Cluster Observability, OpenTelemetry operators |
| 2 | `nvidia-gpu-enablement` | NFD + NVIDIA GPU operator and instances |
| 2 | `leaderworkerset` | Leader Worker Set operator and instance |
| 2 | `rhcl` | Red Hat Connectivity Link + Kuadrant |
| 3 | `gateway-api` | GatewayClass + maas-default-gateway |
| 4 | `openshift-ai` | RHOAI operator, DSC, dashboard, observability DSCI |
| 5 | `maas-postgres` | Postgres for MaaS API key storage |
| 6 | `maas-controller` | MaaS CRDs, RBAC, Kuadrant policies |
| 7 | `llmisvc` | LLMInferenceService models |
| 8 | `maas-subscriptions` | MaaSModelRef, MaaSAuthPolicy, MaaSSubscription |

## Quick Start

### 1. Configure your cluster

```bash
cp -r clusters/example.cluster.opentlc.com clusters/mycluster.mydomain.com
# Edit clusters/mycluster.mydomain.com/cluster.yaml:
#   global.cluster.name
#   global.cluster.baseDomain
#   global.toolsImage
```

Edit platform overrides under `clusters/mycluster.mydomain.com/platform/values/` and workload overrides under `clusters/mycluster.mydomain.com/values/`.

### 2. Update chart dependencies

```bash
for c in rhcl leaderworkerset openshift-ai observability-operators; do
  (cd charts/$c && helm dependency update)
done
```

### 3. Install in wave order

```bash
cd rhoai-3_4-helm
CLUSTER=clusters/example.cluster.opentlc.com
CHARTS=charts

# Wave 1
helm upgrade --install cert-manager $CHARTS/cert-manager -n cert-manager-operator --create-namespace \
  -f $CLUSTER/cluster.yaml -f $CLUSTER/platform/values/cert-manager/values.yaml
helm upgrade --install observability-operators $CHARTS/observability-operators -n openshift-operators --create-namespace \
  -f $CLUSTER/cluster.yaml -f $CLUSTER/platform/values/observability-operators/values.yaml

# Wave 2 (wait for operators to be ready)
helm upgrade --install nvidia-gpu-enablement $CHARTS/nvidia-gpu-enablement -n openshift-nfd --create-namespace \
  -f $CLUSTER/cluster.yaml -f $CLUSTER/platform/values/nvidia-gpu-enablement/values.yaml
helm upgrade --install leaderworkerset $CHARTS/leaderworkerset -n openshift-lws-operator --create-namespace \
  -f $CLUSTER/cluster.yaml -f $CLUSTER/platform/values/leaderworkerset/values.yaml
helm upgrade --install rhcl $CHARTS/rhcl -n kuadrant-system --create-namespace \
  -f $CLUSTER/cluster.yaml -f $CLUSTER/platform/values/rhcl/values.yaml

# Wave 3
helm upgrade --install gateway-api $CHARTS/gateway-api -n openshift-ingress \
  -f $CLUSTER/cluster.yaml -f $CLUSTER/platform/values/gateway-api/values.yaml

# Wave 4
helm upgrade --install openshift-ai $CHARTS/openshift-ai -n redhat-ods-operator --create-namespace \
  -f $CLUSTER/cluster.yaml -f $CLUSTER/platform/values/openshift-ai/values.yaml

# Wave 5
helm upgrade --install maas-postgres $CHARTS/maas-postgres -n redhat-ods-applications \
  -f $CLUSTER/cluster.yaml -f $CLUSTER/platform/values/maas-postgres/values.yaml

# Wave 6
helm upgrade --install maas-controller $CHARTS/maas-controller -n redhat-ods-applications \
  -f $CLUSTER/cluster.yaml -f $CLUSTER/platform/values/maas-controller/values.yaml

# Waves 7–8 (workloads)
helm upgrade --install llmisvc $CHARTS/llmisvc -n ai-models --create-namespace \
  -f $CLUSTER/cluster.yaml -f $CLUSTER/values/llmisvc/values.yaml
helm upgrade --install maas-subscriptions $CHARTS/maas-subscriptions -n models-as-a-service --create-namespace \
  -f $CLUSTER/cluster.yaml -f $CLUSTER/values/maas-subscriptions/values.yaml
```

Wait for each wave's operators and post-install Jobs to complete before proceeding to the next wave.

### Platform readiness checklist

Before installing workload charts (waves 7–8), confirm:

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

### Workload charts

1. `charts/{app}/values.yaml` — chart defaults
2. `clusters/{cluster}/cluster.yaml` — global cluster settings
3. `clusters/{cluster}/values/{app}/values.yaml` — per-app overrides

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

Post-install Jobs use the cluster `toolsImage` (must include `oc` and `jq`) and run as Helm post-install/post-upgrade hooks.

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

# Workload
helm template test charts/llmisvc \
  -f clusters/example.cluster.opentlc.com/cluster.yaml \
  -f clusters/example.cluster.opentlc.com/values/llmisvc/values.yaml
```

Render a chart locally without installing:

```bash
CLUSTER=clusters/example.cluster.opentlc.com

helm template test charts/gateway-api \
  -f $CLUSTER/cluster.yaml \
  -f $CLUSTER/platform/values/gateway-api/values.yaml

helm template test charts/openshift-ai \
  -f $CLUSTER/cluster.yaml \
  -f $CLUSTER/platform/values/openshift-ai/values.yaml
```
