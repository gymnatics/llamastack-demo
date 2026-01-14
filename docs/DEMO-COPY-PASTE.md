# Demo Copy-Paste Snippets (TESTED & WORKING)

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

## Step 6: Iterate LlamaStack (Add Azure + More MCPs)

**Location:** OpenShift Console → Workloads → ConfigMaps → `llama-stack-config` (namespace: `my-first-model`)

### ⚠️ IMPORTANT: Add in this EXACT order!

1. First: Add Azure **Provider**
2. Second: Add Azure **Model** 
3. Third: Add MCP **Servers**

If you add the model before the provider, it will crash!

---

### 6a. Add Azure Provider (FIRST!)

**Find:** `providers:` → `inference:` section

**Add this AFTER the `vllm-inference` entry (around line 20):**

```yaml
      # Provider 2: Azure OpenAI
      - provider_id: azure-openai
        provider_type: remote::azure
        config:
          api_base: ${env.AZURE_OPENAI_ENDPOINT}
          api_key: ${env.AZURE_OPENAI_API_KEY}
          api_version: ${env.AZURE_OPENAI_API_VERSION:=2024-12-01-preview}
```

---

### 6b. Add Azure Model (SECOND)

**Find:** `models:` section

**Add this AFTER the `llama-32-3b-instruct` entry (around line 80):**

```yaml
    # Model 2: Azure OpenAI
    - provider_id: azure-openai
      model_id: gpt-4.1-mini
      provider_model_id: gpt-4.1-mini
      model_type: llm
      metadata:
        description: "Azure OpenAI GPT-4.1 Mini"
        display_name: gpt-4.1-mini (Azure)
```

---

### 6c. Add HR and Jira MCP Servers (THIRD)

**Find:** `tool_groups:` section

**Add this AFTER the `mcp::weather-data` entry (at the end):**

```yaml
    # MCP Server 2: HR Tools
    - toolgroup_id: mcp::hr-tools
      provider_id: model-context-protocol
      mcp_endpoint:
        uri: http://hr-mcp-server.my-first-model.svc.cluster.local:8000/mcp

    # MCP Server 3: Jira/Confluence
    - toolgroup_id: mcp::jira-confluence
      provider_id: model-context-protocol
      mcp_endpoint:
        uri: http://jira-mcp-server.my-first-model.svc.cluster.local:8000/mcp
```

---

## After Saving ConfigMap

**Restart LlamaStack pod:**
1. Go to: **Workloads** → **Pods**
2. Find: `lsd-genai-playground-xxx`
3. Click the **⋮** (3 dots) → **Delete Pod**
4. Wait ~30-45 seconds for new pod to start
5. Verify pod shows `1/1 Running`

---

## Expected Results After Phase 2

| Component | Count |
|-----------|-------|
| **LLM Models** | 132 (1 vLLM + 131 Azure) |
| **MCP Servers** | 3 (Weather + HR + Jira) |
| **Total Tools** | 17 |

---

## Quick Reference URLs

| Resource | URL |
|----------|-----|
| OpenShift Console | `https://console-openshift-console.apps.ocp.f68xw.sandbox580.opentlc.com` |
| OpenShift AI | `https://rhods-dashboard-redhat-ods-applications.apps.ocp.f68xw.sandbox580.opentlc.com` |
| Frontend UI | `https://llamastack-multi-mcp-demo-my-first-model.apps.ocp.f68xw.sandbox580.opentlc.com` |

---

## Troubleshooting

### If pod crashes after saving:

**Error:** `ValueError: Provider 'azure-openai' not found`

**Cause:** You added the model but forgot the provider

**Fix:** 
1. Edit ConfigMap again
2. Make sure the Azure provider is under `providers.inference`
3. Save and delete pod again
