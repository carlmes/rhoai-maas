# RHOAI and Model-as-a-Service Manifests

Manifests for bringing up **Red Hat OpenShift AI (RHOAI) 3** and **Models-as-a-Service (MaaS)** on OpenShift.

## Recommended: Install with Kustomize

Use Kustomize for a repeatable, phased install of the RHOAI 3 operator and its dependencies (NFD, NVIDIA GPU, RHCL, Gateway, DataScienceCluster, MaaS). See **[rhoai-3_3/KUSTOMIZE.md](rhoai-3_3/KUSTOMIZE.md)** 

-----

## Notes
Install maas using kustomize. 

Install notes:
1. Install operators Cert manager and leader worker set

2. Apply lws-operator-cr

3. Install rhcl
~~Make sure csv for rhcl has: - name: ISTIO_GATEWAY_CONTROLLER_NAMES~~

    ~~value: 'istio.io/gateway-controller,openshift.io/gateway-controller/v1'~~

4. Check tls cert for Gateway/maas-default-gateway.yaml in openshift-ingress and apply

5. Apply Kuadrant custom resource in rh-connectivity-link

6. Deploy postgres... MaaS **REQUIRES** a database for RHOAI 3.4. maas-api will look for this database by `maas-db-config` secret.

6. Install rhoai.... Make sure odhdashboard config is updated and dsc is updated. Llamastack needs to be enabled too

7. The Tenant resource is for `maas-controller` deployment. The `default-tenant` lives in `model-as-a-service` namespace. The tenant resource is created by the dsc, but Authorino will need to be updated with the cert.

7.1 Update Kuadrant / rh-connectivity-link ns — service authorinio-authorinio-authorization

```
annotations:
    service.beta.openshift.io/serving-cert-secret-name: authorino-server-cert
```

7.2 Update Authorino authorinio:spec:

```
  clusterWide: true
  healthz: {}
  listener:
    ports: {}
    tls:
      certSecretRef:
        name: authorino-server-cert
      enabled: true
```

8. Update rhoai dashboard with OdhDashboardConfig. Restart rhoai-dashboard pods.

9. Delete kuadrant-operator-controller-manager in rh-connectivity-link if llm doesn’t come up because of authoring. check authpolicy - maas-api-auth-policy (it said to restart kuadrant operator-controller-manager pod).

10. Apply simulated models

11. Apply maas-subscriptions

| Resource | Purpose |
|----------|---------|
| **LLMInferenceService** | The LLM workload — the actual inference service (simulator, vLLM, etc.) |
| **MaaSModelRef** | Gives the MaaS system a reference to the model so it appears in the model catalog |
| **MaaSAuthPolicy** | Grants access to the model for specified groups (who can use it) |
| **MaaSSubscription** | Defines rate limits (token quotas) for specific groups |

12. TokenRatePolicy is automatically created per model. Search for this in the model namespace and update it.

## Validation
[https://opendatahub-io.github.io/models-as-a-service/latest/install/validation/](https://opendatahub-io.github.io/models-as-a-service/latest/install/validation/)

### 1. Get Gateway Endpoint

```bash
CLUSTER_DOMAIN=$(kubectl get ingresses.config.openshift.io cluster -o jsonpath='{.spec.domain}') && \
HOST="https://maas.${CLUSTER_DOMAIN}" && \
echo "Gateway endpoint: $HOST"
```


### 2. Get Authentication Token

For OpenShift:

```bash
TOKEN_RESPONSE=$(curl -sSk \
  -H "Authorization: Bearer $(oc whoami -t)" \
  -H "Content-Type: application/json" \
  -X POST \
  -d '{"expiration": "10m"}' \
  "${HOST}/maas-api/v1/tokens") && \
TOKEN=$(echo $TOKEN_RESPONSE | jq -r .token) && \
echo "Token obtained: ${TOKEN:0:20}..."
```


### 3. List Available Models

```bash
MODELS=$(curl -sSk ${HOST}/maas-api/v1/models \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $TOKEN" | jq -r .) && \
echo $MODELS | jq . && \
MODEL_NAME=$(echo $MODELS | jq -r '.data[0].id') && \
MODEL_URL=$(echo $MODELS | jq -r '.data[0].url') && \
echo "Model URL: $MODEL_URL"
```

### 4. Test Model Inference Endpoint

Send a request to the model endpoint (should get a 200 OK response):

```bash
curl -sSk -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"model\": \"${MODEL_NAME}\", \"prompt\": \"Hello\", \"max_tokens\": 50}" \
  "${MODEL_URL}/v1/completions" | jq
```

### 5. Test Token rate limiting

```bash
for i in {1..16}; do                           
  curl -sSk -o /dev/null -w "%{http_code}\n" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"${MODEL_NAME}\", \"prompt\": \"Hello\", \"max_tokens\": 50}" \
    "${MODEL_URL}/v1/completions"
done
```
