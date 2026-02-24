Manifests for bringing up rhoai and model as a service


Instructions:
1. Install operators in this order:
nfd, nvidia, connectivity link, servicemesh 3, then rhoai3.

2. Create nfd and gpu cluster policy - apply `nfd-instance.yaml` and then `nvidia-cp.yaml`

3. Create namespace `kuadrant-system` - apply `kuadrant-ns.yaml`.

4. Add gateway and gateway class for rhoai - apply `gateway.yaml` & `gatewayclass.yaml`.

5. Create dsc - apply `datasciencecluster.yaml`.

6. Create namespace `maas-api` - apply `maas-ns.yaml`

7. Create maas resources - apply `maas.yaml`