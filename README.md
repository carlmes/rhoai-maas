# RHOAI and Model-as-a-Service Manifests

Manifests for bringing up **Red Hat OpenShift AI (RHOAI) 3** and **Models-as-a-Service (MaaS)** on OpenShift.

## Recommended: Install with Kustomize

Use Kustomize for a repeatable, phased install of the RHOAI 3 operator and its dependencies (NFD, NVIDIA GPU, Kuadrant, Gateway, DataScienceCluster, MaaS). See **[docs/KUSTOMIZE.md](docs/KUSTOMIZE.md)** for:

- Repository layout (`base/` and `overlays/`)
- Phased install order and commands
- Full overlay option
- Customization (channels, DSC, MaaS hostname)

Quick start (phased):

```bash
kustomize build overlays/01-operators | oc apply -f -
# Wait for operators to be ready, then:
kustomize build overlays/02-nfd-nvidia-instances | oc apply -f -
kustomize build overlays/03-kuadrant | oc apply -f -
kustomize build overlays/04-gateway | oc apply -f -
kustomize build overlays/05-dsc | oc apply -f -
kustomize build overlays/06-maas | oc apply -f -
```

## Manual install (legacy)

If you prefer to apply raw manifests by hand:

1. **Operators** (in order): NFD, NVIDIA GPU, Connectivity Link, Service Mesh 3, then RHOAI 3 — from OperatorHub or apply `operators/nfd.yaml`, `operators/nvidia.yaml`, `operators/rhoai.yaml`.
2. **NFD and GPU policy:** apply `instances/nfd-instance.yaml`, then `instances/nvidia-cp.yaml`.
3. **Kuadrant:** apply `instances/kuadrant.yaml`.
4. **Gateway:** apply `instances/gatewayclass.yaml` and `instances/gateway.yaml`.
5. **DataScienceCluster:** apply `instances/datasciencecluster.yaml`.
6. **MaaS:** apply `instances/maas-ns.yaml`, then `instances/maas.yaml`.
Note: update maas.yaml hostnames


-----

Install maas

Install operators Cert manager and lead worker set

Apply lws-operator-cr

Install rhcl
Make sure csv for rhcl has: - name: ISTIO_GATEWAY_CONTROLLER_NAMES
    value: 'istio.io/gateway-controller,openshift.io/gateway-controller/v1'

Check tls cert for Gateway/maas-default-gateway.yaml in openshift-ingress and apply

Apply Kuadrant custom resource in rh-connectivity-link


Install rhoai.... Make sure odhdashboard config is updated and dsc is updated. Llamastack needs to be enabled too

Deploy Postgres with secrets

Deploy auth-policies

Deploy maas-controller …. Auth-policies are same as above

Configuring TLS backend for Authorino and MaaS API..

Restart rollout of deployment Maas-api and authorinio

Delete kuadrant operator controller manager in kuadrant system if llm doesn’t come up because of authoring…..check authpolicy - maas-api-auth-policy (it said to restart kuadrant operator controller manager pod) …. This helps when requesting a token and returning null


Kuadrant / rh-connectivity-link ns — service authoring-authoriniro-authorization
annotations:
    service.beta.openshift.io/serving-cert-secret-name: authorino-server-cert
Also need to update Authorino authorinio:spec:
  clusterWide: true
  healthz: {}
  listener:
    ports: {}
    tls:
      certSecretRef:
        name: authorino-server-cert
      enabled: true

