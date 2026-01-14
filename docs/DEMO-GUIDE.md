# LlamaStack MCP Demo Guide

This guide shows how to demonstrate adding and removing MCP servers from a LlamaStack distribution on OpenShift AI.

---

## Table of Contents

1. [Quick Start](#quick-start)
2. [Multi-Project Demo](#multi-project-demo) ⭐ **Key Demo Feature**
3. [Demo Flow](#demo-flow)
4. [Demo Scenarios](#demo-scenarios)
5. [Manual Steps (For Demo)](#manual-steps-for-demo)
6. [Available MCP Servers](#available-mcp-servers)
7. [Frontend UI](#frontend-ui)
8. [YAML Reference](#yaml-reference)
9. [Troubleshooting](#troubleshooting)

---

## Quick Start

The `deploy.sh` script auto-detects your current namespace. Just run it!

```bash
# Switch to your namespace
oc project my-demo-namespace

# Deploy Phase 1 (Weather MCP only)
./scripts/deploy.sh phase1

# Check status
./scripts/deploy.sh status

# List available tools
./scripts/deploy.sh tools
```

### All Commands

| Command | Description |
|---------|-------------|
| `./scripts/deploy.sh phase1` | Deploy Weather MCP only |
| `./scripts/deploy.sh phase2` | Deploy Weather + HR MCPs |
| `./scripts/deploy.sh full` | Deploy all 4 MCP servers |
| `./scripts/deploy.sh add weather` | Set to Weather only |
| `./scripts/deploy.sh add hr` | Add HR MCP (Weather + HR) |
| `./scripts/deploy.sh add jira` | Add Jira MCP (all MCPs) |
| `./scripts/deploy.sh add github` | Add GitHub MCP (all MCPs) |
| `./scripts/deploy.sh add all` | Add all 4 MCP servers |
| `./scripts/deploy.sh reset` | Reset to Weather only |
| `./scripts/deploy.sh status` | Show pods and routes |
| `./scripts/deploy.sh tools` | List available tools |
| `./scripts/deploy.sh config` | Show current MCP config |

---

## Multi-Project Demo

> ⭐ **Key Demo Feature**: Show how different projects/teams have different LlamaStack distributions with different MCP servers attached.

### Concept

In an enterprise, different teams need different tools:
- **HR Team** → Weather + HR tools
- **Dev Team** → Weather + Jira + GitHub tools  
- **Full Platform** → All tools available

Each team gets their own **namespace** with their own **LlamaStack distribution** configured with only the MCP servers they need.

### Setup Multi-Project Demo

```bash
# Create 3 project namespaces
oc new-project team-hr
oc new-project team-dev
oc new-project team-platform

# Deploy HR Team's LlamaStack (Weather + HR)
oc project team-hr
./scripts/deploy.sh phase2

# Deploy Dev Team's LlamaStack (Weather + Jira + GitHub)
oc project team-dev
./scripts/deploy.sh full

# Deploy Platform Team's LlamaStack (All tools)
oc project team-platform
./scripts/deploy.sh full
```

### Demo Walkthrough

#### Step 1: Show HR Team's Tools

```bash
oc project team-hr
./scripts/deploy.sh tools
```

**Expected output:**
```
Total: 10 tools

mcp::weather-data:
  - getforecast

mcp::hr-tools:
  - get_vacation_balance
  - get_employee_info
  - list_employees
  - list_job_openings
  - create_vacation_request
  - get_performance_review
```

**Demo point:** "HR team only has access to Weather and HR tools - no GitHub or Jira access."

#### Step 2: Show Dev Team's Tools

```bash
oc project team-dev
./scripts/deploy.sh tools
```

**Expected output:**
```
Total: 20+ tools

mcp::weather-data:
  - getforecast

mcp::jira-confluence:
  - search_issues
  - get_issue_details
  - create_issue
  - search_confluence
  - list_projects

mcp::github-tools:
  - search_repositories
  - get_repository
  - list_issues
  - search_code
  - get_user
```

**Demo point:** "Dev team has Weather, Jira, and GitHub - the tools they need for development workflows."

#### Step 3: Compare Configurations

```bash
# Show HR team's config
echo "=== HR Team LlamaStack Config ==="
oc project team-hr
oc get configmap llama-stack-config -o jsonpath='{.data.run\.yaml}' | grep -A4 "toolgroup_id: mcp::"

echo ""
echo "=== Dev Team LlamaStack Config ==="
oc project team-dev
oc get configmap llama-stack-config -o jsonpath='{.data.run\.yaml}' | grep -A4 "toolgroup_id: mcp::"
```

**Demo point:** "Each project has its own LlamaStack ConfigMap with different MCP servers configured."

#### Step 4: Show Different Frontend URLs

```bash
echo "=== Project Frontend URLs ==="
echo ""
echo "HR Team:"
oc get route llamastack-multi-mcp-demo -n team-hr -o jsonpath='{.spec.host}' 2>/dev/null && echo ""
echo ""
echo "Dev Team:"
oc get route llamastack-multi-mcp-demo -n team-dev -o jsonpath='{.spec.host}' 2>/dev/null && echo ""
echo ""
echo "Platform Team:"
oc get route llamastack-multi-mcp-demo -n team-platform -o jsonpath='{.spec.host}' 2>/dev/null && echo ""
```

**Demo point:** "Each team has their own frontend URL. When they open it, they only see the tools available to their team."

### Key Talking Points

1. **Isolation**: Each project has its own LlamaStack distribution
2. **Customization**: Admins configure which MCP servers each team gets
3. **Security**: Teams can't access tools they shouldn't have
4. **Scalability**: Easy to add new teams with different tool sets
5. **YAML-based**: All configuration is declarative and version-controlled

### Quick Multi-Project Setup Script

```bash
#!/bin/bash
# setup-multi-project-demo.sh

# HR Team - Weather + HR
oc new-project team-hr 2>/dev/null || oc project team-hr
./scripts/deploy.sh phase2

# Dev Team - All tools
oc new-project team-dev 2>/dev/null || oc project team-dev
./scripts/deploy.sh full

# Show results
echo ""
echo "=== Multi-Project Demo Ready ==="
echo ""
echo "HR Team (team-hr):"
./scripts/deploy.sh tools 2>/dev/null | head -15

echo ""
echo "Dev Team (team-dev):"
oc project team-dev >/dev/null
./scripts/deploy.sh tools 2>/dev/null | head -20
```

---

## Demo Flow

**Recommended demo sequence:**

```bash
# 1. Start with Weather only
./scripts/deploy.sh phase1
./scripts/deploy.sh tools          # Shows: 3 tools (getforecast)

# 2. Add HR MCP
./scripts/deploy.sh add hr
sleep 30                           # Wait for restart
./scripts/deploy.sh tools          # Shows: 10 tools (Weather + HR)

# 3. Add all MCPs
./scripts/deploy.sh add all
sleep 30
./scripts/deploy.sh tools          # Shows: 23 tools (all 4 MCPs)

# 4. Reset back
./scripts/deploy.sh reset
sleep 30
./scripts/deploy.sh tools          # Back to 3 tools
```

---

## Demo Scenarios

Use these scenarios to demonstrate the AI agent capabilities:

### Scenario 1: Weather Query
```
User: "What's the weather forecast for today?"
Agent: Uses Weather MCP → getforecast tool
Expected: Returns weather forecast data
```

### Scenario 2: HR Self-Service
```
User: "Check the vacation balance for employee EMP001"
Agent: Uses HR MCP → get_vacation_balance tool
Expected: Returns vacation days remaining

User: "List all job openings"
Agent: Uses HR MCP → list_job_openings tool
Expected: Returns available positions
```

### Scenario 3: Developer Workflow
```
User: "Search for open bugs in the DEMO project"
Agent: Uses Jira MCP → search_issues tool
Expected: Returns list of bug tickets

User: "Find documentation about API authentication"
Agent: Uses Jira MCP → search_confluence tool
Expected: Returns relevant Confluence pages
```

### Scenario 4: GitHub Integration
```
User: "Search for popular Kubernetes repositories"
Agent: Uses GitHub MCP → search_repositories tool
Expected: Returns list of repos with stars

User: "List open issues in the kubernetes/kubernetes repo"
Agent: Uses GitHub MCP → list_issues tool
Expected: Returns recent issues
```

### Scenario 5: Multi-Tool Query
```
User: "I need to plan a team offsite. Check employee EMP001's vacation balance 
       and find weather forecasts for potential locations."
Agent: Uses HR MCP + Weather MCP together
Expected: Returns vacation balance AND weather data
```

---

## Manual Steps (For Demo)

Use these steps when demonstrating how to manually add MCP servers via YAML.

### Demo Scenario: Adding HR MCP Server

#### Step 1: View Current Configuration

```bash
echo "📋 Current MCP Configuration:"
oc get configmap llama-stack-config -n my-first-model -o jsonpath='{.data.run\.yaml}' | grep -A4 "toolgroup_id: mcp::"
```

**Expected output (Phase 1 - Weather only):**
```yaml
- toolgroup_id: mcp::weather-data
  provider_id: model-context-protocol
  mcp_endpoint:
    uri: http://mcp-weather.my-first-model.svc.cluster.local:80/sse
```

#### Step 2: Check Current Tools

```bash
echo "🔧 Current tools available:"
oc exec deployment/lsd-genai-playground -n my-first-model -- \
  curl -s http://localhost:8321/v1/tools | \
  python3 -c "import sys,json; data=json.load(sys.stdin); tools=data.get('data',[]); print(f'Total: {len(tools)} tools'); [print(f'  - {t[\"name\"]}') for t in tools]"
```

**Expected output:**
```
Total: 3 tools
  - insert_into_memory
  - knowledge_search
  - getforecast
```

#### Step 3: Apply Phase 2 Configuration (Weather + HR)

```bash
echo "📝 Applying Phase 2 config (Weather + HR)..."
oc create configmap llama-stack-config \
  --from-file=run.yaml=/Users/dayeo/LlamaStack-MCP-Demo/manifests/llamastack/llama-stack-config-phase2.yaml \
  -n my-first-model \
  --dry-run=client -o yaml | oc apply -f -
```

#### Step 4: Restart LlamaStack

```bash
echo "🔄 Restarting LlamaStack to pick up new config..."
oc delete pod -l app=lsd-genai-playground -n my-first-model
```

#### Step 5: Wait for Restart

```bash
echo "⏳ Waiting for LlamaStack to restart..."
sleep 30
oc get pods -n my-first-model | grep lsd
```

#### Step 6: Verify New Configuration

```bash
echo "✅ New MCP Configuration:"
oc get configmap llama-stack-config -n my-first-model -o jsonpath='{.data.run\.yaml}' | grep -A4 "toolgroup_id: mcp::"
```

**Expected output (Phase 2 - Weather + HR):**
```yaml
- toolgroup_id: mcp::weather-data
  provider_id: model-context-protocol
  mcp_endpoint:
    uri: http://mcp-weather.my-first-model.svc.cluster.local:80/sse
- toolgroup_id: mcp::hr-tools
  provider_id: model-context-protocol
  mcp_endpoint:
    uri: http://hr-mcp-server.my-first-model.svc.cluster.local:8000/mcp
```

#### Step 7: Verify New Tools

```bash
echo "🔧 Tools now available:"
oc exec deployment/lsd-genai-playground -n my-first-model -- \
  curl -s http://localhost:8321/v1/tools | \
  python3 -c "
import sys,json
data=json.load(sys.stdin)
tools = data.get('data', [])
print(f'Total: {len(tools)} tools')
print('')
groups = {}
for t in tools:
    g = t.get('toolgroup_id', 'builtin')
    if g not in groups:
        groups[g] = []
    groups[g].append(t['name'])
for g, tlist in groups.items():
    print(f'{g}:')
    for tool in tlist:
        print(f'  - {tool}')
"
```

**Expected output:**
```
Total: 10 tools

builtin::rag:
  - insert_into_memory
  - knowledge_search
mcp::weather-data:
  - getforecast
mcp::hr-tools:
  - get_vacation_balance
  - create_vacation_request
  - get_employee_info
  - list_employees
  - list_job_openings
  - get_performance_review
  - get_vacation_requests
```

#### Step 8: Test the New HR Tools

```bash
echo "🧪 Testing HR tool: get_vacation_balance"
oc exec deployment/lsd-genai-playground -n my-first-model -- \
  curl -s -X POST http://localhost:8321/v1/tool-runtime/invoke \
  -H "Content-Type: application/json" \
  -d '{"tool_name":"get_vacation_balance","toolgroup_id":"mcp::hr-tools","kwargs":{"employee_id":"EMP001"}}' | \
  python3 -c "import sys,json; data=json.load(sys.stdin); print(data.get('content',[{}])[0].get('text','No result'))"
```

---

## Available MCP Servers

| MCP Server | Toolgroup ID | Tools | Endpoint |
|------------|--------------|-------|----------|
| **Weather (Simple)** | `mcp::weather-data` | getforecast | `http://mcp-weather...svc.cluster.local:80/sse` |
| **Weather (MongoDB)** | `mcp::weather-mongodb` | search_weather, get_current_weather, list_stations, get_statistics, health_check | `http://weather-mongodb-mcp...svc.cluster.local:8000/mcp` |
| **HR** | `mcp::hr-tools` | get_vacation_balance, get_employee_info, list_employees, list_job_openings, create_vacation_request, get_performance_review | `http://hr-mcp-server...svc.cluster.local:8000/mcp` |
| **Jira/Confluence** | `mcp::jira-confluence` | search_issues, get_issue_details, create_issue, search_confluence, list_projects | `http://jira-mcp-server...svc.cluster.local:8000/mcp` |
| **GitHub** | `mcp::github-tools` | search_repositories, get_repository, list_issues, search_code, get_user | `http://github-mcp-server...svc.cluster.local:8000/mcp` |

### Weather MCP Options

There are two Weather MCP servers available:

1. **Weather (Simple)** - OpenWeatherMap-based, single tool (`getforecast`) - **Used in this demo**
2. **Weather (MongoDB)** - MongoDB-backed with rich data and multiple tools - Available in `mcp/weather-mongodb/`

---

## Frontend UI

The demo includes an enhanced Streamlit frontend with multi-MCP support.

### Features
- **Multi-MCP Display** - Shows all connected MCP servers
- **Tool Discovery** - Lists all available tools grouped by server
- **User Toggle** - Users can enable/disable MCP servers for their session
- **Admin Mode** - Admins can add/remove MCP servers (set `ADMIN_MODE=true`)

### Accessing the Frontend

```bash
# Get the frontend route
oc get route -n my-first-model | grep frontend

# Or use the LlamaStack demo route
oc get route llamastack-multi-mcp-demo -n my-first-model
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `LLAMASTACK_URL` | LlamaStack service URL | Auto-detected |
| `MODEL_ID` | Model identifier | Auto-detected from LlamaStack |
| `ADMIN_MODE` | Enable admin features | `false` |

### Model Auto-Detection

The frontend automatically detects available models from LlamaStack:

1. Queries `GET /v1/models` endpoint
2. Filters for LLM models (excludes embedding models)
3. Shows a dropdown selector with available models
4. Falls back to text input if models can't be fetched

**No configuration needed** - the model is auto-detected when the frontend starts!

---

## YAML Reference

### The File to Edit

The LlamaStack configuration is stored in a ConfigMap:
```bash
oc get configmap llama-stack-config -n my-first-model -o yaml
```

### The Section to Edit: `tool_groups`

Add or remove entries in the `tool_groups` section:

```yaml
tool_groups:
# Built-in RAG tools (always keep)
- toolgroup_id: builtin::rag
  provider_id: rag-runtime

# MCP Server entries - add/remove as needed:

# Weather MCP
- toolgroup_id: mcp::weather-data
  provider_id: model-context-protocol
  mcp_endpoint:
    uri: http://mcp-weather.my-first-model.svc.cluster.local:80/sse

# HR MCP (add this to enable HR tools)
- toolgroup_id: mcp::hr-tools
  provider_id: model-context-protocol
  mcp_endpoint:
    uri: http://hr-mcp-server.my-first-model.svc.cluster.local:8000/mcp

# Jira/Confluence MCP (add this to enable Jira tools)
- toolgroup_id: mcp::jira-confluence
  provider_id: model-context-protocol
  mcp_endpoint:
    uri: http://jira-mcp-server.my-first-model.svc.cluster.local:8000/mcp

# GitHub MCP (add this to enable GitHub tools)
- toolgroup_id: mcp::github-tools
  provider_id: model-context-protocol
  mcp_endpoint:
    uri: http://github-mcp-server.my-first-model.svc.cluster.local:8000/mcp

server:
  port: 8321
```

### Pre-built Configuration Files

| File | MCP Servers | Tools |
|------|-------------|-------|
| `llama-stack-config-phase1.yaml` | Weather | 3 |
| `llama-stack-config-phase2.yaml` | Weather + HR | 10 |
| `llama-stack-config-full.yaml` | All 4 | 20+ |

### Quick Switch Commands

```bash
# Switch to Phase 1 (Weather only)
oc create configmap llama-stack-config \
  --from-file=run.yaml=/Users/dayeo/LlamaStack-MCP-Demo/manifests/llamastack/llama-stack-config-phase1.yaml \
  -n my-first-model --dry-run=client -o yaml | oc apply -f - && \
  oc delete pod -l app=lsd-genai-playground -n my-first-model

# Switch to Phase 2 (Weather + HR)
oc create configmap llama-stack-config \
  --from-file=run.yaml=/Users/dayeo/LlamaStack-MCP-Demo/manifests/llamastack/llama-stack-config-phase2.yaml \
  -n my-first-model --dry-run=client -o yaml | oc apply -f - && \
  oc delete pod -l app=lsd-genai-playground -n my-first-model

# Switch to Full (All 4 MCP servers)
oc create configmap llama-stack-config \
  --from-file=run.yaml=/Users/dayeo/LlamaStack-MCP-Demo/manifests/llamastack/llama-stack-config-full.yaml \
  -n my-first-model --dry-run=client -o yaml | oc apply -f - && \
  oc delete pod -l app=lsd-genai-playground -n my-first-model
```

---

## Deploy Script Commands Summary

| Command | Description |
|---------|-------------|
| `./scripts/deploy.sh phase1` | Deploy Weather MCP only |
| `./scripts/deploy.sh phase2` | Deploy Weather + HR MCPs |
| `./scripts/deploy.sh full` | Deploy all 4 MCP servers |
| `./scripts/deploy.sh add <mcp>` | Add specific MCP (weather, hr, jira, github, all) |
| `./scripts/deploy.sh reset` | Reset to Weather only |
| `./scripts/deploy.sh status` | Show pods and routes |
| `./scripts/deploy.sh tools` | List available tools |
| `./scripts/deploy.sh config` | Show current MCP config |

---

## Troubleshooting

### LlamaStack not picking up new config
```bash
# Force restart
oc delete pod -l app=lsd-genai-playground -n my-first-model
# Wait and check
sleep 30
oc get pods -n my-first-model | grep lsd
```

### MCP server not connecting
```bash
# Check if MCP server pod is running
oc get pods -n my-first-model | grep mcp

# Check MCP server logs
oc logs deployment/hr-mcp-server -n my-first-model --tail=20
```

### Tools not showing up
```bash
# Check LlamaStack logs for errors
oc logs deployment/lsd-genai-playground -n my-first-model --tail=50 | grep -i error
```
