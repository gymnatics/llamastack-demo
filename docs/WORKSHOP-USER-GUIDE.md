# LlamaStack Workshop - User Guide

> 📋 **Quick reference guide with copy-paste commands for workshop participants**

---

## 🎯 Workshop Overview

| Part | Duration | What You'll Do |
|------|----------|----------------|
| **Part 1** | 45 min | Create project → Hardware profile → Deploy model |
| **Part 2** | 30 min | Deploy MCPs → Enable Playground → Test Weather → Run notebook |
| **Part 3** | 30 min | Update LlamaStack config → Test HR tools |
| **Part 4** | 30 min | Watch admin demo Azure OpenAI |
| **Part 5** | 30 min | Re-run notebook with all tools |

---

## 📝 Before You Start

**Your assigned user number:** `user-XX` (replace XX with your number, e.g., `user-05`)

**Login to OpenShift:**
```bash
oc login --token=<your-token> --server=<cluster-url>
```

---

## Part 1: Create Project & Deploy Model (45 min)

### Step 1.1: Create Your Project

1. Go to **OpenShift AI Dashboard** → **Data Science Projects**
2. Click **Create data science project**
3. Enter:
   - **Name:** `user-XX` (your assigned number)
   - **Description:** `Workshop project`
4. Click **Create**

### Step 1.2: Create Hardware Profile

1. Go to **Settings** → **Hardware profiles**
2. Click **Create hardware profile**
3. Configure:

| Field | Value |
|-------|-------|
| Name | `gpu-profile` |
| Display name | `GPU Profile` |

4. Add identifiers:

| Resource | Identifier | Default | Min | Max |
|----------|------------|---------|-----|-----|
| CPU | `cpu` | 4 | 1 | 8 |
| Memory | `memory` | 16Gi | 8Gi | 32Gi |
| GPU | `nvidia.com/gpu` | 1 | 1 | 1 |

5. Click **Create**

### Step 1.3: Create Model Connection

1. In your project, go to **Connections**
2. Click **Add connection** → **URI**
3. Enter:
   - **Name:** `llama-3.2-3b-instruct`
   - **URI:**
   ```
   oci://quay.io/redhat-ai-services/modelcar-catalog:llama-3.2-3b-instruct
   ```
4. Click **Create**

### Step 1.4: Deploy the Model

1. Go to **Models** → **Deploy model**
2. Configure:
   - **Model name:** `llama-32-3b-instruct`
   - **Serving runtime:** vLLM NVIDIA GPU ServingRuntime for KServe
   - **Hardware profile:** `gpu-profile`
   - **Model connection:** `llama-3.2-3b-instruct`
3. Check ✅ **Make deployed models available as AI assets**
4. Click **Deploy**
5. ⏳ Wait 3-5 minutes for status to show **Running**

### Step 1.5: Verify Model (Optional)

```bash
oc get pods -n user-XX | grep llama
```

Expected output:
```
llama-32-3b-instruct-predictor-xxxxx   1/1   Running
```

---

## Part 2: Deploy MCPs & Enable Playground (30 min)

### Step 2.1: Clone the Workshop Repository

```bash
git clone https://github.com/<org>/llamastack-demo.git
cd llamastack-demo
git checkout workshop-branch
```

### Step 2.2: Deploy Both MCP Servers

```bash
# Set your namespace
export NS=user-XX  # Change XX to your number!

# Deploy Weather MCP
oc apply -f manifests/mcp-servers/weather-mongodb/deploy-weather-mongodb.yaml -n $NS

# Deploy HR MCP
oc apply -f manifests/workshop/deploy-hr-mcp-simple.yaml -n $NS

# Wait for deployments
oc wait --for=condition=available deployment/mongodb -n $NS --timeout=120s
oc wait --for=condition=complete job/init-weather-data -n $NS --timeout=120s
oc wait --for=condition=available deployment/weather-mongodb-mcp -n $NS --timeout=180s
oc wait --for=condition=available deployment/hr-mcp-server -n $NS --timeout=180s

echo "✅ Both MCP servers deployed!"
```

### Step 2.3: Register MCP Endpoints

1. Go to **AI Asset Endpoints** in your project
2. Click **Add endpoint** → **MCP Server**
3. Add Weather MCP:
   - **Name:** `weather-mcp`
   - **URL:** `http://weather-mongodb-mcp:8000/mcp`
4. Add HR MCP:
   - **Name:** `hr-mcp`
   - **URL:** `http://hr-mcp-server:8000/mcp`

### Step 2.4: Enable Playground

1. Go to **AI Asset Endpoints**
2. Find your model `llama-32-3b-instruct`
3. Click **Add to Playground**
4. ⏳ Wait ~2 minutes for LlamaStack Distribution

### Step 2.5: Test in Playground

1. Go to **GenAI Studio** → **Playground**
2. Select your model
3. Try these prompts:

```
What is the capital of France?
```

```
What is the weather in New York City?
```

```
List all available weather stations
```

### Step 2.6: Check Available Tools

```bash
oc exec deployment/lsd-genai-playground -n $NS -- \
  curl -s http://localhost:8321/v1/tools | python3 -c "
import json,sys
data=json.load(sys.stdin)
tools=data if isinstance(data,list) else data.get('data',[])
mcps=[t for t in tools if t.get('toolgroup_id','').startswith('mcp::')]
print(f'MCP Tools: {len(mcps)}')
for t in mcps:
    print(f\"  - {t.get('toolgroup_id')}/{t.get('name')}\")"
```

**Expected:** ~3 Weather tools only

### Step 2.7: Run Notebook (First Time)

1. Go to **Workbenches** → **Create workbench**
   - **Name:** `workshop-notebook`
   - **Image:** Jupyter Data Science (Python 3.12)
2. Click **Create** and wait for it to start
3. Click **Open** to launch JupyterLab
4. In JupyterLab: **Git** → **Clone a Repository**
   ```
   https://github.com/<org>/llamastack-demo.git
   ```
5. Open `llamastack-demo/notebooks/workshop_client_demo.ipynb`
6. Update `PROJECT_NAME = "user-XX"` with your number
7. Run all cells

**Expected:** ~3 tools (Weather MCP only)

---

## Part 3: Update LlamaStack Config (30 min)

### Step 3.1: View Current Config

```bash
oc get configmap llama-stack-config -n $NS -o yaml | grep -A20 "tool_groups:"
```

**Expected:** Only Weather MCP in toolgroup

### Step 3.2: Apply Phase 2 Config

```bash
# Apply new config (adds HR MCP to toolgroup)
oc apply -f manifests/workshop/llama-stack-config-workshop-phase2.yaml -n $NS

# Restart LlamaStack
oc delete pod -l app=lsd-genai-playground -n $NS

# Wait for restart
echo "Waiting for LlamaStack to restart..."
sleep 30
oc wait --for=condition=available deployment/lsd-genai-playground -n $NS --timeout=120s
```

### Step 3.3: Verify New Tools

```bash
oc exec deployment/lsd-genai-playground -n $NS -- \
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

**Expected:**
```
Total tools: 8
  - builtin::rag: 2 tools
  - mcp::hr-tools: 5 tools
  - mcp::weather-data: 1 tools
```

### Step 3.4: Test HR MCP in Playground

Go to **GenAI Studio** → **Playground** and try:

```
List all employees in the company
```

```
What is the vacation balance for employee EMP001?
```

```
What job openings are available?
```

```
Create a vacation request for EMP002 from 2026-02-10 to 2026-02-14
```

**Combined query (uses both MCPs!):**
```
What's the weather in Tokyo and how many vacation days does Alice Johnson have?
```

---

## Part 4: Watch Admin Demo (30 min)

The admin will demonstrate:
- Adding Azure OpenAI as a second inference provider
- Switching between local vLLM and cloud Azure models
- Same API, different backends

**Key Takeaway:** LlamaStack abstracts multiple providers - clients don't need to change!

---

## Part 5: Re-run Notebook (30 min)

### Step 5.1: Re-run the Notebook

1. Open your workbench
2. Open `workshop_client_demo.ipynb`
3. **Restart kernel** (Kernel → Restart Kernel)
4. Run all cells again

### Step 5.2: Compare Results

| Run | MCP Servers | Tools |
|-----|-------------|-------|
| Part 2 (first) | Weather only | ~3 |
| Part 5 (second) | Weather + HR | ~8 |

**Key Learning:** Same notebook code, different results! The code discovers available tools dynamically.

### Step 5.3: Try Combined Queries

In the notebook, modify the query cell:

```python
my_question = "What's the weather in London and list all employees in Engineering?"
```

---

## 🧹 Cleanup (After Workshop)

```bash
# Delete your project
oc delete project user-XX
```

---

## 🔧 Troubleshooting

### Model Not Starting

```bash
# Check pod status
oc get pods -n $NS | grep llama

# Check events
oc get events -n $NS --sort-by='.lastTimestamp' | tail -10

# Check GPU availability
oc describe node -l nvidia.com/gpu.present=true | grep -A5 "Allocated"
```

### Playground Not Working

```bash
# Check LlamaStack pod
oc get pods -n $NS | grep lsd-genai

# Check logs
oc logs deployment/lsd-genai-playground -n $NS --tail=30
```

### MCP Server Not Responding

```bash
# Check MCP pods
oc get pods -n $NS | grep -E "weather|hr"

# Check MCP logs
oc logs deployment/weather-mongodb-mcp -n $NS --tail=20
oc logs deployment/hr-mcp-server -n $NS --tail=20
```

### Notebook Connection Error

Make sure `PROJECT_NAME` matches your actual project name:
```python
PROJECT_NAME = "user-XX"  # Must match your oc project name exactly!
```

---

## 📚 Quick Reference

### Key URLs (Internal)

| Service | URL |
|---------|-----|
| Weather MCP | `http://weather-mongodb-mcp:8000/mcp` |
| HR MCP | `http://hr-mcp-server:8000/mcp` |
| LlamaStack | `http://lsd-genai-playground-service:8321` |

### Key Commands

```bash
# Set namespace
export NS=user-XX

# Check pods
oc get pods -n $NS

# Check MCP tools
oc exec deployment/lsd-genai-playground -n $NS -- curl -s http://localhost:8321/v1/tools

# Check models
oc exec deployment/lsd-genai-playground -n $NS -- curl -s http://localhost:8321/v1/models

# Restart LlamaStack
oc delete pod -l app=lsd-genai-playground -n $NS

# View LlamaStack config
oc get configmap llama-stack-config -n $NS -o yaml
```

---

## ✅ Checklist

- [ ] Created project `user-XX`
- [ ] Created hardware profile with GPU
- [ ] Deployed model (Running status)
- [ ] Deployed Weather MCP
- [ ] Deployed HR MCP
- [ ] Registered both MCP endpoints
- [ ] Enabled Playground
- [ ] Tested Weather queries (Part 2)
- [ ] Ran notebook first time (~3 tools)
- [ ] Applied Phase 2 config
- [ ] Tested HR queries (Part 3)
- [ ] Watched admin Azure demo (Part 4)
- [ ] Ran notebook second time (~8 tools)

---

**🎉 Congratulations! You've completed the LlamaStack Workshop!**
