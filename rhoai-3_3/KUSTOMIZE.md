# Installing RHOAI 3 and Dependencies with Kustomize

This repo uses [Kustomize](https://kustomize.io/) to install Red Hat OpenShift AI (RHOAI) 3, its operator dependencies, and the Models-as-a-Service (MaaS) stack in a repeatable, GitOps-friendly way.

## Install Order (Phased Install — Recommended)

Apply overlays **in order** and wait for each phase to be ready before the next. This matches the original manual sequence and avoids race conditions.

| Phase | Overlay | What it does |
|-------|---------|---------------|
| 1 | `overlays/01-operators` | Installs NFD, NVIDIA GPU, Connectivity Link, Leader Worker Set, and RHOAI operators via OLM |
| 2 | `overlays/02-nfd-nvidia-lws-instances` | Creates NFD instance and NVIDIA ClusterPolicy (GPU nodes) and Lead Worker Set Instance |
| 3 | `overlays/03-gateway` | Creates Gatewayclass and Maas Gateway !! UPDATE HOST NAME !! |
| 4 | `overlays/04-rhoai` | Creates DataScienceCluster and Authorinio NetworkPolicy |
| 5 | `overlays/05-odhdashboard` | Updates teh ODH Dashboard Config to enable MaaS and GenAI studio (only for v3.3?) Has to be installed after DSC |
| 6 | `overlays/06-postgres` | Creates Postgres instance for token storage WIP |
| 7 | `overlays/07-maas-controller` | ~~Creates Maas-controller deployment,~~ Policies, RBAC ~~and CRDS~~ (needed for v3.4) |
| 8 | `overlays/08-simulated-models` | Creates dummy models for testing |

### Commands (phased)

```bash
# From repo root
export KUBECONFIG=...   # or oc login

# Go through the list of folders in overalys and apply them to the cluster
kustomize build overlays/0#-Abcdefg | oc apply -f -

```
