# LlamaStack MCP Workshop Guide

## 🎯 Workshop Overview

**Duration:** ~2-3 hours  
**Participants:** 20 users  
**Format:** Hands-on workshop with admin-led Azure demo

### Workshop Goals

1. Each participant deploys their own local LLM model using vLLM on OpenShift AI
2. Participants explore LlamaStack with MCP servers (Weather)
3. Admin demonstrates Azure OpenAI integration (centralized keys)
4. Participants understand the iteration workflow for LlamaStack distributions

---

## 📋 Workshop Structure

| Phase | Duration | Who | Description |
|-------|----------|-----|-------------|
| **Pre-Setup** | Before | Admin | GPU provisioning, RHOAI + LlamaStack installation |
| **Part 1** | 45 min | Users | Create project, hardware profile, deploy model |
| **Part 2** | 30 min | Users | Test MCP servers in GenAI Playground |
| **Part 3** | 30 min | Admin | Azure OpenAI demo (admin only) |
| **Part 4** | 30 min | Users | Client integration with notebooks |
| **Wrap-up** | 15 min | All | Q&A and cleanup |

---

## 🔧 Pre-Workshop Admin Setup

> ⏰ **Run these steps BEFORE the workshop**

### What Admin Handles

The admin is responsible for:
- **GPU MachineSet** - Provisioning GPU nodes (20 GPUs for 20 participants)
- **RHOAI 3.0 Installation** - Installing OpenShift AI with LlamaStack operator enabled
- **Azure OpenAI Keys** - Only admin has access to Azure API keys

### What Users Will Do (During Workshop)

Users will learn to:
- Create Hardware Profiles
- Create Data Science Projects
- Deploy models with vLLM
- Use GenAI Studio Playground
- Work with MCP servers

---

### Admin Step 1: Provision GPU Nodes

Create a MachineSet with 20 GPUs (or enough for all participants). This is handled separately by the admin.

```bash
# Verify GPU nodes are available
oc get nodes -l nvidia.com/gpu.present=true -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\\.com/gpu
```

### Admin Step 2: Install RHOAI 3.0

Ensure RHOAI 3.0 is installed with the following components enabled in the DataScienceCluster:

```yaml
spec:
  components:
    dashboard:
      managementState: Managed
    kserve:
      managementState: Managed
    llamastackoperator:
      managementState: Managed  # Required for GenAI Playground
    workbenches:
      managementState: Managed
```

Enable GenAI Studio in the OdhDashboardConfig:

```yaml
spec:
  dashboardConfig:
    genAiStudio: true
    modelAsService: true
```

### Admin Step 3: Prepare Azure OpenAI Secret (For Admin Demo Only)

```bash
# Create the Azure secret in your admin namespace
oc create secret generic azure-openai-secret \
  --from-literal=endpoint="https://YOUR-RESOURCE.openai.azure.com/" \
  --from-literal=api-key="YOUR-API-KEY" \
  --from-literal=api-version="2024-12-01-preview" \
  -n <your-admin-namespace>
```

### Admin Step 4: Verify Setup

```bash
# Verify GPU availability (should show 20+ GPUs)
oc get nodes -l nvidia.com/gpu.present=true -o custom-columns=NAME:.metadata.name,GPU:.status.allocatable.nvidia\\.com/gpu

# Verify RHOAI is running
oc get pods -n redhat-ods-applications | grep -E "dashboard|odh"

# Verify LlamaStack operator
oc get pods -n redhat-ods-applications | grep llama
```

---

## 👤 Part 1: User Model Deployment (45 min)

> **Goal:** Each participant creates a project, hardware profile, and deploys Llama 3.2-3B locally using vLLM

### Step 1.1: Create Your Data Science Project

1. Log into OpenShift AI Dashboard
2. Navigate to **Data Science Projects**
3. Click **Create data science project**
4. Fill in:
   - **Name:** `user-XX` (where XX is your assigned number, e.g., `user-01`)
   - **Description:** `Workshop project for user XX`
5. Click **Create**

### Step 1.2: Create a Hardware Profile

Hardware profiles define the compute resources (CPU, Memory, GPU) for your model serving.

1. Navigate to **Settings** → **Hardware profiles**
2. Click **Create hardware profile**
3. Configure:
   - **Name:** `gpu-profile`
   - **Display name:** `GPU Profile`
   - **Description:** `Single GPU profile for model serving`
4. Add resource identifiers:

   | Resource | Identifier | Default | Min | Max |
   |----------|------------|---------|-----|-----|
   | CPU | cpu | 4 | 1 | 8 |
   | Memory | memory | 16Gi | 8Gi | 32Gi |
   | GPU | nvidia.com/gpu | 1 | 1 | 1 |

5. Click **Create**

> **💡 Tip:** Hardware profiles can be reused across multiple model deployments and shared across projects.

**Alternative: Apply via YAML**

```yaml
apiVersion: infrastructure.opendatahub.io/v1
kind: HardwareProfile
metadata:
  annotations:
    opendatahub.io/dashboard-feature-visibility: '[]'
    opendatahub.io/disabled: 'false'
    opendatahub.io/display-name: GPU Profile
  name: gpu-profile
  namespace: redhat-ods-applications
spec:
  identifiers:
    - defaultCount: '4'
      displayName: CPU
      identifier: cpu
      maxCount: '8'
      minCount: 1
      resourceType: CPU
    - defaultCount: 16Gi
      displayName: Memory
      identifier: memory
      maxCount: 32Gi
      minCount: 8Gi
      resourceType: Memory
    - defaultCount: 1
      displayName: GPU
      identifier: nvidia.com/gpu
      maxCount: 1
      minCount: 1
      resourceType: Accelerator
```

### Step 1.3: Create Model Connection

1. In your project, go to **Connections**
2. Click **Add connection**
3. Select **URI** connection type
4. Fill in:
   - **Name:** `llama-3.2-3b-instruct`
   - **URI:** `oci://quay.io/redhat-ai-services/modelcar-catalog:llama-3.2-3b-instruct`
5. Click **Create**

### Step 1.4: Deploy the Model

1. Go to **Models** → **Deploy model**
2. Configure:
   - **Model name:** `llama-32-3b-instruct`
   - **Serving runtime:** vLLM NVIDIA GPU ServingRuntime for KServe
   - **Model framework:** vLLM
   - **Hardware profile:** Select your `gpu-profile`
   - **Model connection:** Select `llama-3.2-3b-instruct`
3. Under **Model server configuration**:
   - Replicas: 1
   - Check "Make deployed models available as AI assets"
4. Click **Deploy**

### Step 1.5: Wait for Model to Start

The model will take 3-5 minutes to start. Monitor progress:
- Status should change from "Pending" → "Running"
- The model pulls from the OCI registry and loads into GPU memory

### Step 1.6: Verify Model is Running

```bash
# From terminal (optional)
oc get pods -n user-XX | grep llama
# Should show: llama-32-3b-instruct-predictor-xxxxx   1/1   Running
```

---

## 🎮 Part 2: GenAI Studio Playground (30 min)

> **Goal:** Test the model and MCP servers in the Playground

### Step 2.1: Enable Playground

1. Go to **AI Asset Endpoints** in your project
2. Find your deployed model `llama-32-3b-instruct`
3. Click **Add to Playground**
4. Wait for the LlamaStack Distribution to be created (~2 min)

### Step 2.2: Access the Playground

1. Navigate to **GenAI Studio** → **Playground**
2. Select your model from the dropdown
3. Test with a simple prompt:

```
What is the capital of France? Answer in one sentence.
```

### Step 2.3: Register Weather MCP Server

The admin has pre-deployed a shared Weather MCP server. Let's add it:

1. Go to **Settings** → **AI asset endpoints**
2. The Weather MCP server should be visible
3. Click the 🔒 icon to "Login" (even without auth, this activates it)

### Step 2.4: Test MCP Integration

In the Playground, try:

```
What is the weather in New York City?
```

You should see:
- The agent calls the `getforecast` tool
- Weather data is returned and summarized

### Step 2.5: Explore Tool Calling

Try more complex queries:

```
Compare the weather in Tokyo and London. Which city is warmer today?
```

---

## 🔐 Part 3: Azure OpenAI Demo (Admin Only - 30 min)

> **Goal:** Admin demonstrates adding Azure OpenAI as a second provider

### What Participants Will See

The admin will demonstrate:
1. How to add Azure OpenAI as a second inference provider
2. Switching between local vLLM and Azure OpenAI
3. The power of LlamaStack's provider abstraction

### Admin Demo Steps

```bash
# 1. Show current Phase 1 config (1 model, 1 MCP)
oc get configmap llama-stack-config -n workshop-admin -o yaml | head -60

# 2. Apply Phase 2 config (adds Azure OpenAI)
oc apply -f manifests/llamastack/llama-stack-config-phase2.yaml

# 3. Restart LlamaStack
oc delete pod -l app=lsd-genai-playground -n workshop-admin

# 4. Verify 2 models now available
oc exec deployment/lsd-genai-playground -n workshop-admin -- \
  curl -s http://localhost:8321/v1/models | python3 -c "
import json,sys
data=json.load(sys.stdin)
llms=[m for m in data.get('data',[]) if m.get('model_type')=='llm']
print(f'LLM Models: {len(llms)}')
for m in llms:
    print(f\"  - {m.get('identifier')} ({m.get('provider_id')})\")"
```

### Key Takeaways for Participants

1. **No code changes needed** - just update the ConfigMap
2. **Secrets stay with admin** - Azure keys never exposed to users
3. **Same API, different backends** - clients don't need to change
4. **Easy iteration** - add/remove providers without redeployment

---

## 📓 Part 4: Client Integration (30 min)

> **Goal:** Use notebooks to interact with LlamaStack programmatically

### Step 4.1: Create a Workbench

1. In your project, go to **Workbenches**
2. Click **Create workbench**
3. Configure:
   - **Name:** `workshop-notebook`
   - **Image:** Jupyter | Data Science | CPU | Python 3.12
   - **Hardware profile:** (use default CPU profile)
4. Click **Create**

### Step 4.2: Upload the Demo Notebook

1. Once the workbench is running, click **Open**
2. Upload `notebooks/workshop_client_demo.ipynb`
3. Open the notebook

### Step 4.3: Run the Notebook

The notebook demonstrates:
1. Listing available models
2. Listing MCP tools
3. Making chat completions
4. Using tool calling

### Step 4.4: Experiment

Try modifying the notebook to:
- Ask different questions
- Use different system prompts
- Explore the tool responses

---

## 🧹 Workshop Cleanup

### For Participants

You can delete your project after the workshop:

1. Go to **Data Science Projects**
2. Click the ⋮ menu next to your project
3. Select **Delete project**

Or via CLI:
```bash
oc delete project user-XX
```

### For Admin

```bash
# Delete all user projects
for i in $(seq -w 1 20); do
  oc delete project user-$i --ignore-not-found=true
done

# Delete admin namespace
oc delete project <admin-namespace> --ignore-not-found=true
```

---

## 🔧 Troubleshooting

### Model Not Starting

```bash
# Check pod status
oc get pods -n user-XX | grep llama

# Check events
oc get events -n user-XX --sort-by='.lastTimestamp' | tail -20

# Check GPU availability
oc describe node <gpu-node> | grep -A5 "Allocated resources"

# Common issues:
# - No GPU available: Wait for other models to finish or check GPU count
# - ImagePullBackOff: Check network connectivity to quay.io
# - OOMKilled: Increase memory in hardware profile
```

### Playground Not Working

```bash
# Check LlamaStack pod
oc get pods -n user-XX | grep lsd-genai

# Check logs
oc logs deployment/lsd-genai-playground -n user-XX --tail=50

# Common issues:
# - Pod not starting: Model must be running first
# - Connection refused: Wait for LlamaStack to initialize (~2 min)
```

### Hardware Profile Not Showing

- Ensure you created the hardware profile in `redhat-ods-applications` namespace
- Check that `opendatahub.io/disabled` annotation is set to `'false'`
- Refresh the browser page

### GPU Not Available

```bash
# Check GPU node status
oc get nodes -l nvidia.com/gpu.present=true

# Check GPU allocations
oc describe node <gpu-node> | grep -A10 "Allocated resources"

# If all GPUs are in use, wait for other participants or contact admin
```

---

## 📚 Additional Resources

- [OpenShift AI 3.0 Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/3.0)
- [LlamaStack Documentation](https://llama-stack.readthedocs.io/)
- [MCP Protocol Specification](https://modelcontextprotocol.io/)

---

## 📊 Workshop Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        OpenShift Cluster                            │
│                   (Admin: GPU nodes + RHOAI 3.0)                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐     │
│  │    user-01      │  │    user-02      │  │    user-XX      │     │
│  │  (User creates) │  │  (User creates) │  │  (User creates) │     │
│  │                 │  │                 │  │                 │     │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │     │
│  │ │ vLLM Model  │ │  │ │ vLLM Model  │ │  │ │ vLLM Model  │ │     │
│  │ │ (1 GPU)     │ │  │ │ (1 GPU)     │ │  │ │ (1 GPU)     │ │     │
│  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │     │
│  │                 │  │                 │  │                 │     │
│  │ ┌─────────────┐ │  │ ┌─────────────┐ │  │ ┌─────────────┐ │     │
│  │ │ LlamaStack  │ │  │ │ LlamaStack  │ │  │ │ LlamaStack  │ │     │
│  │ │ Distribution│ │  │ │ Distribution│ │  │ │ Distribution│ │     │
│  │ └─────────────┘ │  │ └─────────────┘ │  │ └─────────────┘ │     │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘     │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    Admin Namespace                           │   │
│  │  ┌─────────────────────────────────────────────────────┐    │   │
│  │  │ LlamaStack (Admin Demo)                              │    │   │
│  │  │ - vLLM (local model)                                 │    │   │
│  │  │ - Azure OpenAI (keys here only - admin demo)         │    │   │
│  │  └─────────────────────────────────────────────────────┘    │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## ✅ Pre-Workshop Checklist

### Admin Checklist

- [ ] GPU MachineSet created with 20+ GPUs available
- [ ] RHOAI 3.0 installed with LlamaStack operator enabled
- [ ] GenAI Studio enabled in OdhDashboardConfig
- [ ] Azure OpenAI secret created in admin namespace (for demo)
- [ ] User accounts created with access to OpenShift AI dashboard
- [ ] User number assignments ready (user-01 through user-20)

### Participant Checklist

- [ ] OpenShift AI dashboard access confirmed
- [ ] Assigned user number known (e.g., user-05)
- [ ] Browser ready (Chrome/Firefox recommended)
- [ ] Basic understanding of LLMs and APIs
