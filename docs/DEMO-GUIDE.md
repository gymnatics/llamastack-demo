# LlamaStack MCP Demo Guide

## 📹 VIDEO DEMO SCRIPT - EXACT COMMANDS

This guide provides the **exact commands** to run during each step of the video demo.

---

## Table of Contents

1. [Pre-Recording Setup](#pre-recording-setup)
2. [Video Step 1: Deploy MCP Servers](#video-step-1-deploy-mcp-servers-on-openshift)
3. [Video Step 2: Register in AI Assets](#video-step-2-register-mcp-servers-in-ai-assets)
4. [Video Step 3: Test in Playground](#video-step-3-test-in-genai-studio-playground)
5. [Video Step 4: LlamaStack Phase 1](#video-step-4-llamastack-distribution-phase-1)
6. [Video Step 5: Client Integration](#video-step-5-client-integration)
7. [Video Step 6: Iterate LlamaStack](#video-step-6-iterate-llamastack-distribution)
8. [Video Step 7: Show Updated Config](#video-step-7-show-updated-configuration)
9. [Reset Commands](#reset-commands)
10. [Troubleshooting](#troubleshooting)

---

## Pre-Recording Setup

> ⏰ **Run these commands BEFORE starting the video recording**

### 1. Login to Cluster

```bash
oc login --token=sha256~YOUR_TOKEN --server=https://api.YOUR_CLUSTER:6443
```

### 2. Navigate to Project Directory

```bash
cd /Users/dayeo/LlamaStack-MCP-Demo
```

### 3. Reset Demo Environment

```bash
# Delete AI Assets ConfigMap (so you can re-register during demo)
oc delete configmap gen-ai-aa-mcp-servers -n redhat-ods-applications

# Apply Phase 1 LlamaStack config (vLLM + Weather only)
oc apply -f manifests/llamastack/llama-stack-config-phase1.yaml

# Restart LlamaStack to pick up Phase 1 config
oc delete pod -l app=lsd-genai-playground -n my-first-model

# Wait for restart
sleep 30

# Verify Phase 1 is active (should show 1 LLM model, 1 MCP server)
echo "Verifying Phase 1..."
oc exec deployment/lsd-genai-playground -n my-first-model -- \
  curl -s http://localhost:8321/v1/models | python3 -c "
import json,sys
data=json.load(sys.stdin)
llms=[m for m in data.get('data',[]) if m.get('model_type')=='llm']
print(f'Models: {len(llms)}')"

oc exec deployment/lsd-genai-playground -n my-first-model -- \
  curl -s http://localhost:8321/v1/tools | python3 -c "
import json,sys
data=json.load(sys.stdin)
tools=data if isinstance(data,list) else data.get('data',[])
mcps=set(t.get('toolgroup_id','') for t in tools if t.get('toolgroup_id','').startswith('mcp::'))
print(f'MCP Servers: {len(mcps)}')"
```

**Expected Output:**
```
Models: 1
MCP Servers: 1
```

### 4. Verify MCP Pods are Running

```bash
oc get pods -n my-first-model | grep -E "mcp|hr-|jira-|github-"
```

**Expected Output:** All 4 MCP server pods should be Running.

### Pre-Recording Checklist

- [ ] AI Assets ConfigMap deleted
- [ ] LlamaStack on Phase 1 (1 model, 1 MCP)
- [ ] All 4 MCP server pods running
- [ ] Terminal in correct directory
- [ ] Browser tabs ready (OpenShift AI, Frontend)

---

## Video Step 1: Deploy MCP Servers on OpenShift

> 🎬 **Duration: ~2 min**
> 
> **Goal:** Show that 4 MCP servers are deployed as pods

### Commands to Run

```bash
# Show all MCP server pods
oc get pods -n my-first-model | grep -E "mcp|hr-|jira-|github-"
```

**Expected Output:**
```
github-mcp-server-xxxxx    1/1     Running   0          4h
hr-api-xxxxx               1/1     Running   0          5h
hr-mcp-server-xxxxx        1/1     Running   0          5h
jira-mcp-server-xxxxx      1/1     Running   0          5h
mcp-weather-xxxxx          1/1     Running   0          3d
```

### What to Say

> "Here we have 4 MCP servers deployed as pods on OpenShift:
> - **Weather MCP** - provides weather data via OpenWeatherMap
> - **HR MCP** - employee info, vacation balances, job openings
> - **Jira/Confluence MCP** - issue tracking and documentation
> - **GitHub MCP** - repository search and code operations
> 
> These are all running as standard Kubernetes deployments."

### Optional: Show Deployment YAML

```bash
# Show one of the MCP server deployments
cat manifests/mcp-servers/hr-mcp-server.yaml | head -40
```

---

## Video Step 2: Register MCP Servers in AI Assets

> 🎬 **Duration: ~2 min**
> 
> **Goal:** Register MCP servers in OpenShift AI so they appear in the dashboard

### Commands to Run

```bash
# Apply the AI Assets ConfigMap
oc apply -f manifests/ai-assets/gen-ai-aa-mcp-servers.yaml
```

**Expected Output:**
```
configmap/gen-ai-aa-mcp-servers created
```

### What to Say

> "Now let's register these MCP servers as AI Assets in OpenShift AI.
> This ConfigMap tells OpenShift AI about our MCP servers so they appear in the dashboard."

### Show in Browser

1. Open **OpenShift AI Dashboard**: `https://rhods-dashboard-redhat-ods-applications.apps.YOUR_CLUSTER`
2. Navigate to: **Settings** → **AI asset endpoints**
3. Show the 4 MCP servers now appearing

### Optional: Show the ConfigMap Content

```bash
# Show what we just applied
cat manifests/ai-assets/gen-ai-aa-mcp-servers.yaml
```

---

## Video Step 3: Test in GenAI Studio Playground

> 🎬 **Duration: ~3 min**
> 
> **Goal:** Test MCP servers using the built-in AI Playground

### Browser Steps

1. In OpenShift AI Dashboard, go to: **GenAI Studio** → **Playground**
2. Select the **Weather MCP Server** from the list
3. Type a test query:

```
What is the weather in New York?
```

4. Show the tool being called and the response

### What to Say

> "OpenShift AI provides a built-in playground where we can test MCP servers directly.
> Let me select the Weather MCP and ask about the weather...
> 
> You can see the agent is calling the `getforecast` tool from the Weather MCP server.
> This confirms our MCP servers are working correctly."

---

## Video Step 4: LlamaStack Distribution Phase 1

> 🎬 **Duration: ~3 min**
> 
> **Goal:** Show LlamaStack with 1 provider (vLLM) and 1 MCP (Weather)

### Commands to Run

```bash
# Show current LlamaStack configuration
oc get configmap llama-stack-config -n my-first-model -o yaml | grep -A50 "run.yaml:" | head -60
```

### What to Say

> "Now let's look at our LlamaStack Distribution. This is the orchestration layer that connects our LLM to the MCP servers.
> 
> In Phase 1, we have:
> - **1 inference provider**: vLLM running Llama 3.2-3B locally
> - **1 MCP server**: Weather only
> 
> This is a minimal configuration - perfect for a team that only needs weather data."

### Show Models and Tools via API

```bash
# Show available models (should be 1)
oc exec deployment/lsd-genai-playground -n my-first-model -- \
  curl -s http://localhost:8321/v1/models | python3 -m json.tool | grep -A3 '"model_type": "llm"'
```

```bash
# Show available tools (should show Weather only)
oc exec deployment/lsd-genai-playground -n my-first-model -- \
  curl -s http://localhost:8321/v1/tools | python3 -c "
import json,sys
data=json.load(sys.stdin)
tools=data if isinstance(data,list) else data.get('data',[])
for t in tools:
    print(f\"  - {t.get('toolgroup_id')}: {t.get('name')}\")"
```

**Expected Output:**
```
  - builtin::rag: insert_into_memory
  - builtin::rag: knowledge_search
  - mcp::weather-data: getforecast
```

---

## Video Step 5: Client Integration

> 🎬 **Duration: ~3 min**
> 
> **Goal:** Show how clients can discover models and tools

### Option A: Use Frontend UI

```bash
# Get Frontend URL
echo "https://$(oc get route llamastack-multi-mcp-demo -n my-first-model -o jsonpath='{.spec.host}')"
```

Open the URL and show:
1. **Model dropdown** - should show only `vllm-inference/llama-32-3b-instruct`
2. **MCP sidebar** - should show only Weather MCP
3. **Refresh button** - to reload from LlamaStack

### Option B: Use Jupyter Notebook

Upload `notebooks/llamastack_client_demo.ipynb` to a Workbench and run cells to show:
- Listing models
- Listing tools
- Making a chat completion

### What to Say

> "Clients can easily discover what's available in LlamaStack.
> 
> Right now we see:
> - **1 model**: Our local vLLM running Llama 3.2-3B
> - **1 MCP server**: Weather with the getforecast tool
> 
> The client automatically detects these from LlamaStack's API."

### Sample Code to Show

```python
import requests

# List models
response = requests.get("http://llamastack:8321/v1/models")
models = [m for m in response.json()["data"] if m["model_type"] == "llm"]
print(f"Available models: {len(models)}")

# List tools
response = requests.get("http://llamastack:8321/v1/tools")
tools = response.json()
print(f"Available tools: {len(tools)}")
```

---

## Video Step 6: Iterate LlamaStack Distribution

> 🎬 **Duration: ~3 min**
> 
> **Goal:** Add 2 more MCPs + Azure OpenAI provider

### Commands to Run

```bash
# Show the Phase 2 config (what we're about to apply)
echo "=== Phase 2 adds: ==="
echo "  - Azure OpenAI provider"
echo "  - HR MCP server"
echo "  - Jira/Confluence MCP server"
echo ""

# Apply Phase 2 configuration
oc apply -f manifests/llamastack/llama-stack-config-phase2.yaml
```

**Expected Output:**
```
configmap/llama-stack-config configured
```

```bash
# Restart LlamaStack to pick up new config
oc delete pod -l app=lsd-genai-playground -n my-first-model

echo "Waiting for LlamaStack to restart..."
sleep 30

# Verify pod is running
oc get pods -n my-first-model | grep lsd-genai-playground
```

### What to Say

> "Now let's iterate our LlamaStack Distribution. I'm going to:
> 1. Add **Azure OpenAI** as a second inference provider
> 2. Add **HR MCP** for employee management
> 3. Add **Jira/Confluence MCP** for project tracking
> 
> This is all done by updating a single ConfigMap - no code changes needed.
> 
> *[Apply the config]*
> 
> Now I'll restart the LlamaStack pod to pick up the new configuration...
> 
> *[Wait for restart]*"

### Show the Diff (Optional)

```bash
# Show what changed
diff manifests/llamastack/llama-stack-config-phase1.yaml \
     manifests/llamastack/llama-stack-config-phase2.yaml | head -50
```

---

## Video Step 7: Show Updated Configuration

> 🎬 **Duration: ~4 min**
> 
> **Goal:** Show 2 models, 3 MCPs, and demo switching providers

### Commands to Run

```bash
# Verify new models (should be 2)
oc exec deployment/lsd-genai-playground -n my-first-model -- \
  curl -s http://localhost:8321/v1/models | python3 -c "
import json,sys
data=json.load(sys.stdin)
llms=[m for m in data.get('data',[]) if m.get('model_type')=='llm']
print(f'LLM Models: {len(llms)}')
for m in llms:
    print(f\"  - {m.get('identifier')} ({m.get('provider_id')})\")"
```

**Expected Output:**
```
LLM Models: 2
  - vllm-inference/llama-32-3b-instruct (vllm-inference)
  - azure-openai/gpt-4.1-mini (azure-openai)
```

```bash
# Verify new tools (should show 3 MCP servers)
oc exec deployment/lsd-genai-playground -n my-first-model -- \
  curl -s http://localhost:8321/v1/tools | python3 -c "
import json,sys
data=json.load(sys.stdin)
tools=data if isinstance(data,list) else data.get('data',[])
groups={}
for t in tools:
    tg=t.get('toolgroup_id','')
    if tg not in groups: groups[tg]=0
    groups[tg]+=1
print(f'Total tools: {len(tools)}')
for tg,count in sorted(groups.items()):
    print(f'  - {tg}: {count} tools')"
```

**Expected Output:**
```
Total tools: 13
  - builtin::rag: 2 tools
  - mcp::hr-tools: 5 tools
  - mcp::jira-confluence: 5 tools
  - mcp::weather-data: 1 tools
```

### Refresh Frontend UI

```bash
# Restart frontend to pick up changes
oc delete pod -l app=llamastack-multi-mcp-demo -n my-first-model
sleep 15

# Get URL
echo "https://$(oc get route llamastack-multi-mcp-demo -n my-first-model -o jsonpath='{.spec.host}')"
```

Open the Frontend and show:
1. **Model dropdown** now has 2 options
2. **MCP sidebar** now shows 3 servers (Weather, HR, Jira)
3. **Switch between models** - select Azure OpenAI

### Demo HR MCP

Type in the chat:
```
List all employees
```

### What to Say

> "After the restart, let's see what's changed...
> 
> Now we have:
> - **2 models**: Local vLLM AND Azure OpenAI
> - **3 MCP servers**: Weather, HR, and Jira
> 
> *[Show Frontend]*
> 
> The frontend automatically detected the new models and MCP servers.
> I can now switch between local vLLM and Azure OpenAI with a single dropdown.
> 
> Let me test the HR MCP by asking to list employees...
> 
> *[Type query and show response]*
> 
> The agent is now using the HR MCP to fetch employee data.
> 
> This demonstrates how easy it is to iterate on a LlamaStack Distribution - 
> just update the YAML and restart. No code changes, no redeployment of the application."

---

## Reset Commands

### Full Reset (Before Recording)

```bash
cd /Users/dayeo/LlamaStack-MCP-Demo

# 1. Delete AI Assets
oc delete configmap gen-ai-aa-mcp-servers -n redhat-ods-applications

# 2. Apply Phase 1 config
oc apply -f manifests/llamastack/llama-stack-config-phase1.yaml

# 3. Restart LlamaStack
oc delete pod -l app=lsd-genai-playground -n my-first-model

# 4. Restart Frontend
oc delete pod -l app=llamastack-multi-mcp-demo -n my-first-model

# 5. Wait
sleep 30

# 6. Verify
echo "=== Verification ==="
oc get pods -n my-first-model | grep -E "lsd-genai|llamastack-multi"
```

### Quick Reset (Between Takes)

```bash
# Just reset LlamaStack to Phase 1
oc apply -f manifests/llamastack/llama-stack-config-phase1.yaml
oc delete pod -l app=lsd-genai-playground -n my-first-model
sleep 30
```

---

## Troubleshooting

### LlamaStack Pod Not Starting

```bash
# Check pod status
oc get pods -n my-first-model | grep lsd

# Check logs
oc logs deployment/lsd-genai-playground -n my-first-model --tail=50
```

### Tools Not Showing Up

```bash
# Check LlamaStack config
oc get configmap llama-stack-config -n my-first-model -o yaml | grep -A5 "tool_groups"

# Force restart
oc delete pod -l app=lsd-genai-playground -n my-first-model
```

### Frontend Not Updating

```bash
# Force restart frontend
oc delete pod -l app=llamastack-multi-mcp-demo -n my-first-model
sleep 15
```

### Azure OpenAI Not Working

```bash
# Check if secret exists
oc get secret azure-openai-secret -n my-first-model

# Check LlamaStack logs for Azure errors
oc logs deployment/lsd-genai-playground -n my-first-model | grep -i azure
```

---

## Quick Reference Card

| Step | Action | Command |
|------|--------|---------|
| **1** | Show MCP pods | `oc get pods -n my-first-model \| grep -E "mcp\|hr-\|jira-\|github-"` |
| **2** | Register AI Assets | `oc apply -f manifests/ai-assets/gen-ai-aa-mcp-servers.yaml` |
| **3** | Test in Playground | *(Browser: OpenShift AI → GenAI Studio → Playground)* |
| **4** | Show Phase 1 | `oc exec deployment/lsd-genai-playground -- curl -s http://localhost:8321/v1/tools` |
| **5** | Show Frontend | `echo "https://$(oc get route llamastack-multi-mcp-demo -n my-first-model -o jsonpath='{.spec.host}')"` |
| **6** | Apply Phase 2 | `oc apply -f manifests/llamastack/llama-stack-config-phase2.yaml && oc delete pod -l app=lsd-genai-playground -n my-first-model` |
| **7** | Verify Phase 2 | `oc exec deployment/lsd-genai-playground -- curl -s http://localhost:8321/v1/models` |

---

## URLs

| Resource | URL |
|----------|-----|
| **Frontend UI** | `https://llamastack-multi-mcp-demo-my-first-model.apps.ocp.f68xw.sandbox580.opentlc.com` |
| **OpenShift AI** | `https://rhods-dashboard-redhat-ods-applications.apps.ocp.f68xw.sandbox580.opentlc.com` |

---

## Files Reference

| File | Purpose |
|------|---------|
| `manifests/llamastack/llama-stack-config-phase1.yaml` | vLLM + Weather only |
| `manifests/llamastack/llama-stack-config-phase2.yaml` | vLLM + Azure + Weather + HR + Jira |
| `manifests/ai-assets/gen-ai-aa-mcp-servers.yaml` | AI Assets registration |
| `manifests/mcp-servers/*.yaml` | MCP server deployments |
| `notebooks/llamastack_client_demo.ipynb` | Client integration demo |
