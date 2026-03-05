# Installing RHOAI 3 and Dependencies with Kustomize

This repo uses [Kustomize](https://kustomize.io/) to install Red Hat OpenShift AI (RHOAI) 3, its operator dependencies, and the Models-as-a-Service (MaaS) stack in a repeatable, GitOps-friendly way.

## Prerequisites

- OpenShift 4.x cluster with admin access
- [kubectl](https://kubernetes.io/docs/tasks/tools/) (with built-in Kustomize) or standalone `kustomize`
- **Optional but recommended for full stack:** Install from OperatorHub before or in parallel if not already present:
  - **Red Hat OpenShift Service Mesh 3** (with Gateway API enabled; required for gateway/auth flows used by MaaS)
  - **cert-manager Operator for Red Hat OpenShift** (required by Connectivity Link for TLS)

## Repository Layout

```
.
├── base/                         # Reusable building blocks
│   ├── operators/                # OLM subscriptions and namespaces
│   │   ├── nfd/                  # Node Feature Discovery
│   │   ├── nvidia/               # NVIDIA GPU Operator
│   │   ├── connectivity-link/    # Red Hat Connectivity Link (Kuadrant/rhcl-operator)
│   │   └── rhoai/                # Red Hat OpenShift AI 3
│   └── instances/                # Operator instances and app resources
│       ├── nfd/                  # NFD instance (NodeFeatureDiscovery CR)
│       ├── nvidia/               # NVIDIA ClusterPolicy
│       ├── kuadrant/             # Kuadrant namespace + Kuadrant CR
│       ├── gateway/              # GatewayClass + Gateway (OpenShift AI inference)
│       ├── dsc/                  # DataScienceCluster (RHOAI core)
│       └── maas/                 # MaaS namespace + API, routes, auth, rate limits
├── overlays/
│   ├── 01-operators/             # NFD, NVIDIA, Connectivity Link, RHOAI operators
│   ├── 02-nfd-nvidia-instances/  # NFD instance + GPU ClusterPolicy
│   ├── 03-kuadrant/              # Kuadrant for gateway auth
│   ├── 04-gateway/               # Gateway + GatewayClass
│   ├── 05-dsc/                   # DataScienceCluster
│   ├── 06-maas/                  # MaaS API and policies
│   └── full/                     # All of the above in one overlay (no ordering)
├── operators/                    # Legacy raw manifests (kept for reference)
├── instances/                    # Legacy raw manifests (kept for reference)
└── docs/
    └── KUSTOMIZE.md              # This file
```

## Install Order (Phased Install — Recommended)

Apply overlays **in order** and wait for each phase to be ready before the next. This matches the original manual sequence and avoids race conditions.

| Phase | Overlay | What it does |
|-------|---------|---------------|
| 1 | `overlays/01-operators` | Installs NFD, NVIDIA GPU, Connectivity Link, and RHOAI operators via OLM |
| 2 | `overlays/02-nfd-nvidia-instances` | Creates NFD instance and NVIDIA ClusterPolicy (GPU nodes) |
| 3 | `overlays/03-kuadrant` | Creates Kuadrant CR in `kuadrant-system` (namespace created in phase 1 by Connectivity Link) |
| 4 | `overlays/04-gateway` | Creates GatewayClass and Gateway for OpenShift AI inference |
| 5 | `overlays/05-dsc` | Creates DataScienceCluster (KServe, dashboard, workbenches, etc.) |
| 6 | `overlays/06-maas` | Creates MaaS namespace, API, HTTPRoutes, AuthPolicy, RateLimitPolicy |

### Commands (phased)

```bash
# From repo root
export KUBECONFIG=...   # or oc login

# 1. Operators
kustomize build overlays/01-operators | oc apply -f -
# Wait for NFD, NVIDIA, Connectivity Link, and RHOAI operators to be installed and ready (oc get csv -A).

# 2. NFD + NVIDIA instances
kustomize build overlays/02-nfd-nvidia-instances | oc apply -f -
# Wait for NFD to label nodes and NVIDIA to roll out driver/device-plugin if using GPUs.

# 3. Kuadrant
kustomize build overlays/03-kuadrant | oc apply -f -

# 4. Gateway
kustomize build overlays/04-gateway | oc apply -f -

# 5. DataScienceCluster
kustomize build overlays/05-dsc | oc apply -f -
# Wait for DSC and sub-components (KServe, etc.) to become ready.

# 6. MaaS
kustomize build overlays/06-maas | oc apply -f -
```

## Full Overlay (Single Apply)

You can build and apply everything in one shot with `overlays/full`. Resource order in the generated manifest is not guaranteed; for production, prefer the phased overlays so you can wait between steps.

```bash
kustomize build overlays/full | oc apply -f -
```

## Customization

- **RHOAI channel:** Edit `base/operators/rhoai/rhoai.yaml` and change `spec.channel` (e.g. `fast-3.x`).
- **NVIDIA ClusterPolicy:** Edit `base/instances/nvidia/nvidia-cp.yaml` (driver, MIG, toolkit, etc.).
- **DataScienceCluster components:** Edit `base/instances/dsc/datasciencecluster.yaml` to enable/disable or tune components (KServe, workbenches, dashboard, etc.).
- **GenAI Playground:** Enabled by default via `base/instances/dsc/odh-dashboard-config-genaistudio.yaml` (OdhDashboardConfig with `genAiStudio: true`). Requires Llama Stack Operator managed in the DSC (already set).
- **MaaS hostname / TLS:** The MaaS Gateway in `base/instances/maas/maas.yaml` uses a placeholder hostname and `${CERT_NAME}`; override in a custom overlay (e.g. `overlays/my-env`) using `patches` or a replacement manifest.

### Example: Overlay with a different RHOAI channel

Create `overlays/prod/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - ../../base/operators/nfd
  - ../../base/operators/nvidia
  - ../../base/operators/rhoai
  # ... add other bases as needed

patches:
  - path: rhods-channel.yaml
```

And `overlays/prod/rhods-channel.yaml`:

```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhods-operator
  namespace: redhat-ods-operator
spec:
  channel: stable-3.x  # or your chosen channel
```

Then: `kustomize build overlays/prod | oc apply -f -`

## Dependencies Summary

| Component | Purpose |
|-----------|--------|
| **NFD** | Node feature discovery (e.g. PCI device labels for GPU nodes). |
| **NVIDIA GPU Operator** | GPU drivers, device plugin, DCGM, toolkit on GPU nodes. |
| **Connectivity Link** | Red Hat Connectivity Link (rhcl-operator); provides Kuadrant, Authorino, Limitador, DNS. Installed in `kuadrant-system`. |
| **RHOAI 3** | Red Hat OpenShift AI operator (RHODS); provides DataScienceCluster, KServe, etc. |
| **Kuadrant** | Kuadrant CR (from overlay 03); configures auth and rate limiting for the gateway. |
| **Gateway / GatewayClass** | OpenShift ingress and KServe inference gateway. |
| **DataScienceCluster** | Enables KServe, model registry, workbenches, dashboard, pipelines, etc. |
| **MaaS** | Models-as-a-Service API, tier-based access, and rate limits. |

## Legacy Manifests

The `operators/` and `instances/` directories contain the original raw YAML. They are kept for reference and backward compatibility. The **canonical** definitions for the Kustomize flow live under `base/` (with copies of manifests there so that Kustomize can build from a single tree).

## See also

- [README.md](../README.md) — High-level repo overview and legacy manual steps.
- [Red Hat OpenShift AI](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/) documentation.
