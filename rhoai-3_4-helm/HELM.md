# RHOAI 3.4 Helm Charts

Helm-based GitOps layout for deploying RHOAI 3.4 and Models-as-a-Service (MaaS), following the pattern from [openshift-setup](https://github.com/jharmison-redhat/openshift-setup).

The existing Kustomize tree at [`rhoai-3_4/`](../rhoai-3_4/) and [`bootstrap.sh`](../bootstrap.sh) are unchanged. Use this directory for Helm/ArgoCD deployments.

## Directory Layout

```
rhoai-3_4-helm/
├── charts/                    # Reusable Helm charts
├── clusters/                  # Per-cluster values
│   └── example.cluster.opentlc.com/
│       ├── cluster.yaml       # Global cluster settings
│       └── values/{app}/      # Per-app overrides
├── applications-templates/    # ArgoCD Application templates
└── HELM.md
```

## Install Order (Sync Waves)

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
| 7 | `llmisvc` | Simulated LLMInferenceService models |
| 8 | `maas-subscriptions` | MaaSModelRef, MaaSAuthPolicy, MaaSSubscription |

## Quick Start

### 1. Configure your cluster

Copy the example cluster directory and update `cluster.yaml`:

```bash
cp -r clusters/example.cluster.opentlc.com clusters/mycluster.mydomain.com
# Edit clusters/mycluster.mydomain.com/cluster.yaml:
#   global.cluster.name
#   global.cluster.baseDomain
```

### 2. Render a chart locally

```bash
CLUSTER=clusters/example.cluster.opentlc.com

helm template test charts/gateway-api \
  -f $CLUSTER/cluster.yaml \
  -f $CLUSTER/values/gateway-api/values.yaml

helm template test charts/llmisvc \
  -f $CLUSTER/cluster.yaml \
  -f $CLUSTER/values/llmisvc/values.yaml

helm template test charts/openshift-ai \
  -f $CLUSTER/cluster.yaml
```

### 3. Install manually (phased)

```bash
CLUSTER=clusters/example.cluster.opentlc.com
CHARTS=charts

# Wave 1
helm upgrade --install cert-manager $CHARTS/cert-manager -n cert-manager-operator --create-namespace
helm upgrade --install observability $CHARTS/observability-operators -n openshift-operators

# Wave 2 (wait for operators)
helm upgrade --install nvidia $CHARTS/nvidia-gpu-enablement -n openshift-nfd
helm upgrade --install lws $CHARTS/leaderworkerset -n openshift-lws-operator
helm upgrade --install rhcl $CHARTS/rhcl -n kuadrant-system

# Wave 3
helm upgrade --install gateway $CHARTS/gateway-api -n openshift-ingress \
  -f $CLUSTER/cluster.yaml -f $CLUSTER/values/gateway-api/values.yaml

# Wave 4
helm upgrade --install rhoai $CHARTS/openshift-ai -n redhat-ods-operator \
  -f $CLUSTER/cluster.yaml

# Wave 5-8
helm upgrade --install maas-postgres $CHARTS/maas-postgres -n redhat-ods-applications
helm upgrade --install maas-controller $CHARTS/maas-controller -n openshift-ingress
helm upgrade --install llmisvc $CHARTS/llmisvc -n ai-models \
  -f $CLUSTER/cluster.yaml -f $CLUSTER/values/llmisvc/values.yaml
helm upgrade --install maas-subscriptions $CHARTS/maas-subscriptions -n models-as-a-service
```

## Value Layering

Charts merge values in this order (later overrides earlier):

1. `charts/{app}/values.yaml` — chart defaults
2. `clusters/{cluster}/cluster.yaml` — global cluster name/domain
3. `clusters/{cluster}/values/{app}/values.yaml` — per-app overrides

The gateway hostname is templated from cluster globals, eliminating the manual hostname patch in `bootstrap.sh`:

```
maas.apps.{cluster.name}.{cluster.baseDomain}
```

## ArgoCD GitOps

Application templates in `applications-templates/` follow the openshift-setup pattern. Fill `helm.valueFiles` with cluster-specific paths when generating Applications:

```yaml
helm:
  valueFiles:
    - ../../clusters/example.cluster.opentlc.com/cluster.yaml
    - ../../clusters/example.cluster.opentlc.com/values/gateway-api/values.yaml
```

## Imperative Post-Install Steps

These steps from [`bootstrap.sh`](../bootstrap.sh) are not yet fully automated in Helm charts. Perform them after the relevant sync wave:

1. **After RHCL operator (wave 2):** Patch RHCL CSV `ISTIO_GATEWAY_CONTROLLER_NAMES` to `istio.io/gateway-controller,openshift.io/gateway-controller/v1`
2. **After RHCL operator (wave 2):** Enable `kuadrant-console-plugin` in OpenShift Console
3. **After openshift-ai (wave 4):** Annotate Authorino service with serving cert, patch Authorino CR for TLS, restart kuadrant-operator-controller-manager
4. **After maas-postgres (wave 5):** Create `maas-db-config` secret from `postgres-creds`, restart `maas-api` deployment
5. **After maas-subscriptions (wave 8):** Patch `default-tenant` telemetry in `models-as-a-service` namespace
6. **After openshift-ai (wave 4):** Restart `rhods-dashboard` pods to pick up OdhDashboardConfig changes

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
  -f clusters/example.cluster.opentlc.com/values/gateway-api/values.yaml \
  | grep -A5 "kind: Gateway"

kustomize build ../rhoai-3_4/overlays/03-gateway | grep -A5 "kind: Gateway"
```

Update chart dependencies after cloning:

```bash
for c in rhcl leaderworkerset openshift-ai observability-operators; do
  (cd charts/$c && helm dependency update)
done
```
