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

Install maas - Mar 6

Install operators Cert manager and lead worker set

Apply lws-operator-cr

Install rhcl
Make sure csv for rhcl has: - name: ISTIO_GATEWAY_CONTROLLER_NAMES
    value: 'istio.io/gateway-controller,openshift.io/gateway-controller/v1'

Check tls cert for Gateway/maas-default-gateway.yaml in openshift-ingress and apply

Apply Kuadrant custom resource in rh-connectivity-link


Install rhoai.... Make sure odhdashboard config is updated and dsc is updated. Llamastack needs to be enabled too

Deploy Postgres with secrets

Configuring TLS backend for Authorino and MaaS API..


simulated LLMInferenceServices:

```
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  annotations:
    alpha.maas.opendatahub.io/tiers: '[]'
  name: simulated
  namespace: models
  finalizers:
    - serving.kserve.io/llmisvc-finalizer
spec:
  model:
    name: facebook/opt-125m
    uri: 'hf://sshleifer/tiny-gpt2'
  replicas: 1
  router:
    gateway:
      refs:
        - name: maas-default-gateway
          namespace: openshift-ingress
    route: {}
  template:
    containers:
      - resources:
          limits:
            cpu: 500m
            memory: 512Mi
          requests:
            cpu: 100m
            memory: 256Mi
        readinessProbe:
          httpGet:
            path: /ready
            port: https
            scheme: HTTPS
        name: main
        command:
          - /app/llm-d-inference-sim
        livenessProbe:
          httpGet:
            path: /health
            port: https
            scheme: HTTPS
        env:
          - name: POD_NAME
            valueFrom:
              fieldRef:
                apiVersion: v1
                fieldPath: metadata.name
          - name: POD_NAMESPACE
            valueFrom:
              fieldRef:
                apiVersion: v1
                fieldPath: metadata.namespace
        ports:
          - containerPort: 8000
            name: https
            protocol: TCP
        imagePullPolicy: Always
        image: 'ghcr.io/llm-d/llm-d-inference-sim:v0.7.1'
        args:
          - '--port'
          - '8000'
          - '--model'
          - facebook/opt-125m
          - '--mode'
          - random
          - '--ssl-certfile'
          - /var/run/kserve/tls/tls.crt
          - '--ssl-keyfile'
          - /var/run/kserve/tls/tls.key
```

premium tier:

```
apiVersion: serving.kserve.io/v1alpha1
kind: LLMInferenceService
metadata:
  annotations:
    alpha.maas.opendatahub.io/tiers: '["premium"]'
  name: simulated-premium
  namespace: models
  finalizers:
    - serving.kserve.io/llmisvc-finalizer
spec:
  model:
    name: facebook/opt-125m
    uri: 'hf://facebook/opt-125m'
  replicas: 1
  router:
    gateway:
      refs:
        - name: maas-default-gateway
          namespace: openshift-ingress
    route: {}
  template:
    containers:
      - resources: {}
        readinessProbe:
          httpGet:
            path: /ready
            port: https
            scheme: HTTPS
        name: main
        command:
          - /app/llm-d-inference-sim
        livenessProbe:
          httpGet:
            path: /health
            port: https
            scheme: HTTPS
        env:
          - name: POD_NAME
            valueFrom:
              fieldRef:
                apiVersion: v1
                fieldPath: metadata.name
          - name: POD_NAMESPACE
            valueFrom:
              fieldRef:
                apiVersion: v1
                fieldPath: metadata.namespace
        ports:
          - containerPort: 8000
            name: https
            protocol: TCP
        imagePullPolicy: Always
        image: 'ghcr.io/llm-d/llm-d-inference-sim:v0.7.1'
        args:
          - '--port'
          - '8000'
          - '--model'
          - facebook/opt-125m
          - '--mode'
          - random
          - '--ssl-certfile'
          - /var/run/kserve/tls/tls.crt
          - '--ssl-keyfile'
          - /var/run/kserve/tls/tls.key

```