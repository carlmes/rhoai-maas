| Resource | Purpose |
|----------|---------|
| **LLMInferenceService** | The LLM workload — the actual inference service (simulator, vLLM, etc.) |
| **MaaSModelRef** | Gives the MaaS system a reference to the model so it appears in the model catalog |
| **MaaSAuthPolicy** | Grants access to the model for specified groups (who can use it) |
| **MaaSSubscription** | Defines rate limits (token quotas) for specific groups |

TokenRatePolicy is automatically created per model. Search for this in the model namespace and update it.