# RHOAI and Model-as-a-Service Manifests

Manifests for bringing up **Red Hat OpenShift AI (RHOAI) 3** and **Models-as-a-Service (MaaS)** on OpenShift.

## Recommended: Install with Kustomize

Use Kustomize for a repeatable, phased install of the RHOAI 3 operator and its dependencies (NFD, NVIDIA GPU, RHCL, Gateway, DataScienceCluster, MaaS). See **[rhoai-3_3/KUSTOMIZE.md](rhoai-3_3/KUSTOMIZE.md)** 

-----

## Notes
Install maas using kustomize. See **[rhoai-3_3/KUSTOMIZE.md](rhoai-3_3/KUSTOMIZE.md)** 

Install notes:
1. Install operators Cert manager and lead worker set

2. Apply lws-operator-cr

3. Install rhcl
Make sure csv for rhcl has: - name: ISTIO_GATEWAY_CONTROLLER_NAMES
    value: 'istio.io/gateway-controller,openshift.io/gateway-controller/v1'

4. Check tls cert for Gateway/maas-default-gateway.yaml in openshift-ingress and apply

5. Apply Kuadrant custom resource in rh-connectivity-link


6. Install rhoai.... Make sure odhdashboard config is updated and dsc is updated. Llamastack needs to be enabled too

7. Deploy Postgres with secrets

8. Deploy auth-policies

9. Configuring TLS backend for Authorino and MaaS API..

10. Restart rollout of deployment Maas-api and authorinio

11. Delete kuadrant operator controller manager in kuadrant system if llm doesn’t come up because of authoring…..check authpolicy - maas-api-auth-policy (it said to restart kuadrant operator controller manager pod) …. This helps when requesting a token and returning null

Kuadrant / rh-connectivity-link ns — service authoring-authoriniro-authorization

```
annotations:
    service.beta.openshift.io/serving-cert-secret-name: authorino-server-cert
```

11. Also need to update Authorino authorinio:spec:

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
```