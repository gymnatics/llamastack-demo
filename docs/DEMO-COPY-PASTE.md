# Demo Copy-Paste Snippets

Use these snippets when editing YAML in the OpenShift Console UI.

---

## Step 2: Add Weather MCP to AI Assets

**Location:** OpenShift Console → Workloads → ConfigMaps → `gen-ai-aa-mcp-servers` (namespace: `redhat-ods-applications`)

**Add this under `data:`:**

```yaml
  Weather-MCP-Server: |
    {
      "url": "http://mcp-weather.my-first-model.svc.cluster.local:80/sse",
      "description": "Weather data MCP server providing real-time weather information via OpenWeatherMap API.",
      "transport": "sse"
    }
```

---

## Step 6: Add Azure OpenAI Provider

**Location:** OpenShift Console → Workloads → ConfigMaps → `llama-stack-config` (namespace: `my-first-model`)

### 6a. Add Azure Provider (under `providers.inference`)

Find the `inference:` section and add this after the vllm-inference entry:

```yaml
      - provider_id: azure-openai
        provider_type: remote::azure
        config:
          api_base: ${env.AZURE_OPENAI_ENDPOINT}
          api_key: ${env.AZURE_OPENAI_API_KEY}
          api_version: ${env.AZURE_OPENAI_API_VERSION:=2024-12-01-preview}
```

### 6b. Add Azure Model (under `models`)

Find the `models:` section and add this after the llama-32-3b-instruct entry:

```yaml
    - provider_id: azure-openai
      model_id: gpt-4.1-mini
      provider_model_id: gpt-4.1-mini
      model_type: llm
      metadata:
        description: "Azure OpenAI GPT-4.1 Mini"
        display_name: gpt-4.1-mini (Azure)
```

### 6c. Add HR and Jira MCP Servers (under `tool_groups`)

Find the `tool_groups:` section and add these after the mcp::weather-data entry:

```yaml
    - toolgroup_id: mcp::hr-tools
      provider_id: model-context-protocol
      mcp_endpoint:
        uri: http://hr-mcp-server.my-first-model.svc.cluster.local:8000/mcp

    - toolgroup_id: mcp::jira-confluence
      provider_id: model-context-protocol
      mcp_endpoint:
        uri: http://jira-mcp-server.my-first-model.svc.cluster.local:8000/mcp
```

---

## After Saving ConfigMap

**Restart LlamaStack pod:**
1. Go to: Workloads → Pods
2. Find: `lsd-genai-playground-xxx`
3. Click the 3 dots → Delete Pod
4. Wait ~30 seconds for new pod to start

---

## Quick Reference URLs

| Resource | URL |
|----------|-----|
| OpenShift Console | `https://console-openshift-console.apps.ocp.f68xw.sandbox580.opentlc.com` |
| OpenShift AI | `https://rhods-dashboard-redhat-ods-applications.apps.ocp.f68xw.sandbox580.opentlc.com` |
| Frontend UI | `https://llamastack-multi-mcp-demo-my-first-model.apps.ocp.f68xw.sandbox580.opentlc.com` |
