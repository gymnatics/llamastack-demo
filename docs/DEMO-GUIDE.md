# LlamaStack MCP Demo Guide

This guide shows how to demonstrate adding and removing MCP servers from a LlamaStack distribution.

---

## Table of Contents

1. [Quick Start with Script](#quick-start-with-script)
2. [Manual Steps (For Demo)](#manual-steps-for-demo)
3. [Available MCP Servers](#available-mcp-servers)
4. [YAML Reference](#yaml-reference)

---

## Quick Start with Script

The `deploy-demo.sh` script provides easy commands to manage MCP servers.

### View Current Configuration
```bash
./scripts/deploy-demo.sh config
```

### Add MCP Servers
```bash
# Add HR MCP (Weather + HR)
./scripts/deploy-demo.sh add hr

# Add ALL MCP servers (Weather + HR + Jira + GitHub)
./scripts/deploy-demo.sh add all
```

### Reset to Weather Only
```bash
./scripts/deploy-demo.sh reset
```

### List Available Tools
```bash
./scripts/deploy-demo.sh tools
```

### Use Different Namespace
```bash
NAMESPACE=my-custom-ns ./scripts/deploy-demo.sh add hr
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

1. **Weather (Simple)** - OpenWeatherMap-based, single tool (`getforecast`)
2. **Weather (MongoDB)** - MongoDB-backed with rich data and multiple tools

To deploy the MongoDB Weather MCP:
```bash
./scripts/deploy-demo.sh deploy-weather-mongodb
```

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

## Demo Script Commands Summary

| Command | Description |
|---------|-------------|
| `./scripts/deploy-demo.sh config` | Show current MCP configuration |
| `./scripts/deploy-demo.sh add hr` | Add HR MCP (Weather + HR) |
| `./scripts/deploy-demo.sh add all` | Add all 4 MCP servers |
| `./scripts/deploy-demo.sh reset` | Reset to Weather only |
| `./scripts/deploy-demo.sh tools` | List all available tools |
| `./scripts/deploy-demo.sh deploy-weather-mongodb` | Deploy MongoDB Weather MCP |

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
