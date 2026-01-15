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
| **Part 2** | 30 min | Users | Phase 1 - Enable Playground with Weather MCP |
| **Part 3** | 30 min | Users | Phase 2 - Iterate LlamaStack config (add more MCPs) |
| **Part 4** | 30 min | Admin | Azure OpenAI demo (admin only) |
| **Part 5** | 30 min | Users | Client integration with notebooks |
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

## 🎮 Part 2: Phase 1 - Deploy Weather MCP & Enable Playground (30 min)

> **Goal:** Deploy Weather MCP server in your project and enable the Playground

### Step 2.1: Deploy Weather MCP Server

Each user deploys their own MCP server in their project:

```bash
# Deploy Weather MCP (MongoDB + MCP Server)
oc apply -f manifests/mcp-servers/weather-mongodb/deploy-weather-mongodb.yaml -n user-XX

# Wait for MongoDB to be ready
oc wait --for=condition=available deployment/mongodb -n user-XX --timeout=120s

# Wait for data initialization
oc wait --for=condition=complete job/init-weather-data -n user-XX --timeout=120s

# Wait for MCP server to be ready
oc wait --for=condition=available deployment/weather-mongodb-mcp -n user-XX --timeout=180s
```

### Step 2.2: Enable Playground

1. Go to **AI Asset Endpoints** in your project
2. Find your deployed model `llama-32-3b-instruct`
3. Click **Add to Playground**
4. Wait for the LlamaStack Distribution to be created (~2 min)

### Step 2.3: Access the Playground

1. Navigate to **GenAI Studio** → **Playground**
2. Select your model from the dropdown
3. Test with a simple prompt:

```
What is the capital of France? Answer in one sentence.
```

### Step 2.4: Test Weather MCP Integration

In the Playground, try:

```
What is the weather in New York City?
```

You should see:
- The agent calls the weather tool
- Weather data is returned and summarized

Try more queries:
```
List all available weather stations
```

```
Compare the weather in Tokyo and London
```

### Step 2.5: Check Current Configuration

Let's see what tools are currently available:

```bash
# Check available tools (should show Weather only)
oc exec deployment/lsd-genai-playground -n user-XX -- \
  curl -s http://localhost:8321/v1/tools | python3 -c "
import json,sys
data=json.load(sys.stdin)
tools=data if isinstance(data,list) else data.get('data',[])
mcps=set(t.get('toolgroup_id','') for t in tools if t.get('toolgroup_id','').startswith('mcp::'))
print(f'MCP Servers: {len(mcps)}')
for mcp in sorted(mcps):
    print(f'  - {mcp}')"
```

**Expected Output (Phase 1):**
```
MCP Servers: 1
  - mcp::weather-data
```

---

## 🔄 Part 3: Phase 2 - Iterate LlamaStack (Add HR MCP) (30 min)

> **Goal:** Learn how to iterate your LlamaStack distribution by adding another MCP server

This is the key learning: **LlamaStack configurations can be updated without code changes!**

### Step 3.1: Deploy HR MCP Server

First, deploy the HR MCP server in your project:

```bash
# Deploy HR MCP server
oc apply -f manifests/workshop/deploy-hr-mcp-simple.yaml -n user-XX

# Wait for it to be ready
oc wait --for=condition=available deployment/hr-mcp-server -n user-XX --timeout=180s
```

### Step 3.2: View Current LlamaStack Config

```bash
# View the current LlamaStack configuration
oc get configmap llama-stack-config -n user-XX -o yaml | grep -A20 "tool_groups:"
```

You should see only the Weather MCP in the `tool_groups` section.

### Step 3.3: Apply Phase 2 Configuration

Now let's update LlamaStack to include the HR MCP server:

```bash
# Apply the Phase 2 config (adds HR MCP)
oc apply -f manifests/workshop/llama-stack-config-workshop-phase2.yaml -n user-XX

# Restart LlamaStack to pick up the new config
oc delete pod -l app=lsd-genai-playground -n user-XX

# Wait for restart
echo "Waiting for LlamaStack to restart..."
sleep 30
```

### Step 3.4: Verify New Tools Are Available

```bash
# Check tools again (should now show 2 MCP servers)
oc exec deployment/lsd-genai-playground -n user-XX -- \
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

**Expected Output (Phase 2):**
```
Total tools: 8
  - builtin::rag: 2 tools
  - mcp::hr-tools: 5 tools
  - mcp::weather-data: 1 tools
```

### Step 3.5: Test HR MCP in Playground

Go back to the **GenAI Studio Playground** and try:

**List employees:**
```
List all employees in the company
```

**Get employee info:**
```
What is the vacation balance for employee EMP001?
```

**Job openings:**
```
What job openings are available?
```

**Create vacation request:**
```
Create a vacation request for EMP002 from 2026-02-10 to 2026-02-14
```

### Step 3.6: Key Takeaways

| Phase 1 | Phase 2 |
|---------|---------|
| 1 MCP Server (Weather) | 2 MCP Servers (Weather + HR) |
| 3 tools | 8 tools |
| Weather queries only | Weather + Employee management |

**What you learned:**
1. ✅ Deploy MCP servers as simple Kubernetes deployments
2. ✅ LlamaStack configs are just YAML - easy to modify
3. ✅ Adding MCP servers requires no code changes to your app
4. ✅ Just update ConfigMap and restart the pod
5. ✅ New tools are automatically discovered by clients

---

## 🔐 Part 4: Azure OpenAI Demo (Admin Only - 30 min)

> **Goal:** Admin demonstrates adding Azure OpenAI as a second inference provider

### What Participants Will See

You just learned how to add MCP servers. Now the admin will show you how to add a **second inference provider** (Azure OpenAI) - demonstrating that LlamaStack can abstract multiple LLM backends.

The admin will demonstrate:
1. How to add Azure OpenAI as a second inference provider
2. Switching between local vLLM and Azure OpenAI
3. The power of LlamaStack's provider abstraction

### Admin Demo Steps

```bash
# 1. Show current config (1 model - vLLM only)
oc get configmap llama-stack-config -n <admin-namespace> -o yaml | head -60

# 2. Apply config with Azure OpenAI added
oc apply -f manifests/llamastack/llama-stack-config-phase2.yaml -n <admin-namespace>

# 3. Restart LlamaStack
oc delete pod -l app=lsd-genai-playground -n <admin-namespace>

# 4. Verify 2 models now available
oc exec deployment/lsd-genai-playground -n <admin-namespace> -- \
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
  - llama-32-3b-instruct (vllm-inference)
  - gpt-4.1-mini (azure-openai)
```

### Key Takeaways for Participants

| What You Did (Part 3) | What Admin Did (Part 4) |
|-----------------------|-------------------------|
| Added MCP servers (tools) | Added inference provider (model) |
| Weather → Weather + HR + Jira | vLLM → vLLM + Azure OpenAI |
| No secrets needed | Requires Azure API keys |

**The Pattern:**
1. ✅ **No code changes needed** - just update the ConfigMap
2. ✅ **Secrets stay with admin** - Azure keys never exposed to users
3. ✅ **Same API, different backends** - clients don't need to change
4. ✅ **Easy iteration** - add/remove providers/tools without redeployment

---

## 📓 Part 5: Client Integration (30 min)

> **Goal:** Use notebooks to interact with LlamaStack programmatically

### Step 5.1: Create a Workbench

1. In your project, go to **Workbenches**
2. Click **Create workbench**
3. Configure:
   - **Name:** `workshop-notebook`
   - **Image:** Jupyter | Data Science | CPU | Python 3.12
   - **Hardware profile:** (use default CPU profile)
4. Click **Create**

### Step 5.2: Get the Demo Notebook

Once the workbench is running, click **Open** to launch JupyterLab.

**Option A: Clone the Git Repository (Recommended)**

1. In JupyterLab, click **Git** → **Clone a Repository**
2. Enter the repository URL:
   ```
   https://github.com/<org>/llamastack-demo.git
   ```
3. Click **Clone**
4. Navigate to `llamastack-demo/notebooks/workshop_client_demo.ipynb`

**Option B: Download and Upload**

1. Download the notebook from the workshop materials (provided by admin)
2. In JupyterLab, click the **Upload** button (⬆️) in the file browser
3. Select `workshop_client_demo.ipynb` from your computer
4. Click **Open** to upload

**Option C: Create from Terminal**

1. In JupyterLab, open a **Terminal** (File → New → Terminal)
2. Run:
   ```bash
   curl -O https://raw.githubusercontent.com/<org>/llamastack-demo/workshop-branch/notebooks/workshop_client_demo.ipynb
   ```
3. The notebook will appear in the file browser

### Step 5.3: Open the Notebook

1. Double-click `workshop_client_demo.ipynb` to open it
2. **Important:** Update the `PROJECT_NAME` variable in the second cell to match your project:
   ```python
   PROJECT_NAME = "user-XX"  # Change XX to your number!
   ```

### Step 5.4: Run the Notebook

The notebook demonstrates:
1. Listing available models
2. Listing MCP tools (you should now see all 3 MCP servers from Phase 2!)
3. Making chat completions
4. Using tool calling

### Step 5.5: Experiment

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

### Phase 1 → Phase 2 Progression (User)

```
Phase 1 (Initial):                    Phase 2 (After Iteration):
┌─────────────────────┐               ┌─────────────────────┐
│     user-XX         │               │     user-XX         │
│                     │               │                     │
│ ┌─────────────────┐ │               │ ┌─────────────────┐ │
│ │ vLLM Model      │ │               │ │ vLLM Model      │ │
│ │ (1 GPU)         │ │               │ │ (1 GPU)         │ │
│ └─────────────────┘ │               │ └─────────────────┘ │
│                     │               │                     │
│ ┌─────────────────┐ │               │ ┌─────────────────┐ │
│ │ Weather MCP     │ │               │ │ Weather MCP     │ │
│ └─────────────────┘ │               │ └─────────────────┘ │
│                     │               │ ┌─────────────────┐ │
│                     │    ──────►    │ │ HR MCP (NEW!)   │ │
│                     │   Deploy +    │ └─────────────────┘ │
│ ┌─────────────────┐ │   Update      │ ┌─────────────────┐ │
│ │ LlamaStack      │ │   ConfigMap   │ │ LlamaStack      │ │
│ │ Tools: 3        │ │               │ │ Tools: 8        │ │
│ └─────────────────┘ │               │ └─────────────────┘ │
└─────────────────────┘               └─────────────────────┘
```

### Full Workshop Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        OpenShift Cluster                            │
│                   (Admin: GPU nodes + RHOAI 3.0)                    │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌───────────────────────────────────────────────────────────────┐ │
│  │                    User Projects (x20)                         │ │
│  │                                                                │ │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌───────────────┐  │ │
│  │  │    user-01      │  │    user-02      │  │   user-XX     │  │ │
│  │  │                 │  │                 │  │               │  │ │
│  │  │ • vLLM (1 GPU)  │  │ • vLLM (1 GPU)  │  │ • vLLM (1 GPU)│  │ │
│  │  │ • Weather MCP   │  │ • Weather MCP   │  │ • Weather MCP │  │ │
│  │  │ • HR MCP        │  │ • HR MCP        │  │ • HR MCP      │  │ │
│  │  │ • LlamaStack    │  │ • LlamaStack    │  │ • LlamaStack  │  │ │
│  │  └─────────────────┘  └─────────────────┘  └───────────────┘  │ │
│  │                                                                │ │
│  │  Each user deploys everything in their own isolated project    │ │
│  └───────────────────────────────────────────────────────────────┘ │
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
- [ ] Workshop repo accessible (public GitHub or internal)

### Participant Checklist

- [ ] OpenShift AI dashboard access confirmed
- [ ] Assigned user number known (e.g., user-05)
- [ ] Browser ready (Chrome/Firefox recommended)
- [ ] Terminal access to run `oc` commands
- [ ] Basic understanding of LLMs and APIs
