# LlamaStack MCP Demo Guide

A comprehensive guide for demonstrating LlamaStack with multiple MCP servers on OpenShift AI.

---

## Table of Contents

1. [Demo Strategy](#demo-strategy) ⭐ **Start Here**
2. [Pre-Demo Setup](#pre-demo-setup)
3. [Demo Day Flow](#demo-day-flow)
4. [Demo Scenarios](#demo-scenarios)
5. [Quick Reference Commands](#quick-reference-commands)
6. [Backup & Recovery](#backup--recovery)
7. [Available MCP Servers](#available-mcp-servers)
8. [YAML Reference](#yaml-reference)
9. [Troubleshooting](#troubleshooting)

---

## Demo Strategy

### Recommended Approach: **Hybrid**

| What | When | Why |
|------|------|-----|
| **Multi-Project Setup** | Pre-demo (day before) | Shows "end state" without waiting |
| **Live MCP Addition** | During demo | Shows "how to do it" |
| **Frontend Demo** | During demo | Interactive, engaging |

### Why Hybrid?

| Approach | Pros | Cons |
|----------|------|------|
| All Live | Shows real deployment | Risk of failures, 5-10 min waiting |
| All Pre-setup | Fast, smooth | Doesn't show "how to do it" |
| **Hybrid** ✅ | Best of both worlds | Requires some prep |

### Demo Timeline (~30 min)

| Section | Duration | What to Show |
|---------|----------|--------------|
| Intro | 2 min | Architecture, what MCP is |
| Live Deploy | 8 min | Add HR MCP in `my-first-model` |
| Multi-Project | 8 min | Show team-ops, team-hr, team-dev |
| Frontend Demo | 10 min | Interactive queries |
| Q&A | 5 min | Questions |

---

## Pre-Demo Setup

> ⏰ **Do this the day before or morning of the demo**

### Step 1: Setup Multi-Project Demo (Pre-setup)

This creates team namespaces that you'll show as the "end state":

```bash
# Login to cluster
oc login --token=<your-token> --server=<your-server>

# Go to your project directory
cd /Users/dayeo/LlamaStack-MCP-Demo

# Set up team namespaces (creates team-ops, team-hr, team-dev)
./scripts/deploy.sh multi setup

# Wait for pods to start (~60 seconds)
sleep 60

# Verify all running
./scripts/deploy.sh multi status
```

**Expected output:**
```
📁 team-ops - Ops Team - Weather only
   MCP Servers: 1
   Pods: 2/2 running

📁 team-hr - HR Team - Weather + HR tools
   MCP Servers: 2
   Pods: 3/3 running

📁 team-dev - Dev Team - All development tools
   MCP Servers: 4
   Pods: 5/5 running
```

### Step 2: Reset `my-first-model` to Phase 1

This gives you a "clean slate" for the live demo:

```bash
# Switch to main namespace
oc project my-first-model

# Reset to Weather only (Phase 1)
./scripts/deploy.sh reset

# Wait for restart
sleep 30

# Verify - should show 3 tools
./scripts/deploy.sh tools
```

**Expected output:**
```
Total: 3 tools
  - insert_into_memory
  - knowledge_search
  - getforecast
```

### Step 3: Verify Frontend is Accessible

```bash
# Get frontend URL
oc get route -n my-first-model | grep frontend

# Or get LlamaStack demo route
oc get route llamastack-multi-mcp-demo -n my-first-model -o jsonpath='{.spec.host}'
```

Open the URL in browser and verify it loads.

### Pre-Demo Checklist

- [ ] Multi-project namespaces running (`./scripts/deploy.sh multi status`)
- [ ] `my-first-model` reset to Phase 1 (3 tools)
- [ ] Frontend UI accessible
- [ ] Terminal ready with correct namespace (`oc project my-first-model`)
- [ ] Demo scenarios tested

---

## Demo Day Flow

### Part 1: Introduction (2 min)

**Show the architecture diagram** (from PRD or slides):

```
┌─────────────────────────────────────────────────────────────────┐
│                    OpenShift AI Cluster                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐         │
│  │  Frontend   │───▶│ LlamaStack  │───▶│ Llama 3.2   │         │
│  │ (Streamlit) │    │Distribution │    │   (vLLM)    │         │
│  └─────────────┘    └──────┬──────┘    └─────────────┘         │
│                            │                                     │
│              ┌─────────────┼─────────────┐                      │
│              │             │             │                      │
│              ▼             ▼             ▼                      │
│  ┌───────────────┐ ┌───────────────┐ ┌───────────────┐         │
│  │  Weather MCP  │ │    HR MCP     │ │   Jira MCP    │         │
│  └───────────────┘ └───────────────┘ └───────────────┘         │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

**Key talking points:**
- "LlamaStack is the orchestration layer between the LLM and external tools"
- "MCP (Model Context Protocol) is how AI agents connect to external services"
- "Each MCP server provides specific tools - Weather, HR, Jira, GitHub"

---

### Part 2: Live Deployment Demo (8 min)

> **Namespace:** `my-first-model`

**Goal:** Show the process of adding MCP servers live

#### Step 1: Show Current State (1 min)

```bash
# Show current status
./scripts/deploy.sh status

# Show current tools (should be 3)
./scripts/deploy.sh tools
```

**Say:** "Right now we only have the Weather MCP server connected. Let's add HR tools."

#### Step 2: Add HR MCP Server (3 min)

```bash
# Add HR MCP
./scripts/deploy.sh add hr
```

**While waiting (~30 seconds), explain:**
- "The script is updating the LlamaStack ConfigMap"
- "This is all YAML-based - no code changes needed"
- "Admins control which tools teams can access"

#### Step 3: Verify New Tools (2 min)

```bash
# Check tools now available
./scripts/deploy.sh tools
```

**Expected output:**
```
Total: 8 tools
  - insert_into_memory
  - knowledge_search
  - getforecast
  - get_vacation_balance
  - get_employee_info
  - list_employees
  - list_job_openings
  - create_vacation_request
```

**Say:** "Now we have 8 tools - the original Weather tools plus 5 HR tools."

#### Step 4: Show the Configuration Change (2 min)

```bash
# Show what changed in the config
./scripts/deploy.sh config
```

**Say:** "This is the ConfigMap that controls which MCP servers are connected. Admins edit this YAML to add or remove tools for their teams."

---

### Part 3: Multi-Project Demo (8 min)

> **Namespaces:** `team-ops`, `team-hr`, `team-dev` (pre-setup)

**Goal:** Show how different teams have different tool access

#### Step 1: Explain the Concept (1 min)

**Say:** "In an enterprise, different teams need different tools:
- Ops team only needs monitoring tools
- HR team needs employee management tools
- Dev team needs everything for full workflow"

#### Step 2: Show Team Status (1 min)

```bash
# Show all team namespaces
./scripts/deploy.sh multi status
```

#### Step 3: Compare Team Tools (4 min)

```bash
# Ops Team - minimal (3 tools)
oc project team-ops
./scripts/deploy.sh tools

# HR Team - more tools (8 tools)
oc project team-hr
./scripts/deploy.sh tools

# Dev Team - all tools (17 tools)
oc project team-dev
./scripts/deploy.sh tools
```

**Say after each:**
- **Ops:** "Ops team only has Weather tools - minimal footprint for monitoring."
- **HR:** "HR team has Weather + HR tools - they can check vacation balances."
- **Dev:** "Dev team has all 17 tools - full development workflow with Jira and GitHub."

#### Step 4: Key Takeaways (2 min)

**Say:**
1. "Each team has their own LlamaStack distribution"
2. "Admins control access via YAML configuration"
3. "No code changes needed - just update the ConfigMap"
4. "All changes are auditable and version-controlled"

---

### Part 4: Interactive Frontend Demo (10 min)

> **Use the Frontend UI**

#### Step 1: Open Frontend

```bash
# Get the frontend URL (use team-dev for all tools)
oc project team-dev
oc get route -n team-dev | grep frontend
```

Open the URL in browser.

#### Step 2: Demo Scenarios

**Scenario 1: Weather Query**
```
Type: "What's the weather forecast for today?"
```
Watch the agent use the Weather MCP.

**Scenario 2: HR Self-Service**
```
Type: "Check the vacation balance for employee EMP001"
```
Watch the agent use the HR MCP.

**Scenario 3: Multi-Tool Query**
```
Type: "List all employees in Engineering and check the weather"
```
Watch the agent use multiple MCPs together.

#### Step 3: Show Tool Selection (2 min)

In the sidebar, show:
- The list of connected MCP servers
- The toggle buttons to enable/disable servers
- The auto-detected model

**Say:** "Users can choose which tools they want to use. Admins control what's available, users control what they use."

---

### Part 5: Q&A (5 min)

Common questions to prepare for:
- "How do you add a new MCP server?" → Show the YAML config
- "Can users add their own MCP servers?" → No, admin-only via YAML
- "How does authentication work?" → MCP servers can require tokens
- "What about security?" → Namespace isolation, RBAC

---

## Demo Scenarios

Use these scenarios during the interactive demo:

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
Expected: Returns "15 vacation days remaining"

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
```

### Scenario 5: Multi-Tool Query
```
User: "I need to plan a team offsite. Check employee EMP001's vacation balance 
       and find weather forecasts for potential locations."
Agent: Uses HR MCP + Weather MCP together
Expected: Returns vacation balance AND weather data
```

---

## Quick Reference Commands

### Pre-Demo Setup
```bash
./scripts/deploy.sh multi setup    # Create team namespaces
./scripts/deploy.sh reset          # Reset my-first-model to Phase 1
```

### Live Demo
```bash
./scripts/deploy.sh status         # Show pods and routes
./scripts/deploy.sh tools          # List available tools
./scripts/deploy.sh add hr         # Add HR MCP
./scripts/deploy.sh config         # Show current MCP config
```

### Multi-Project Demo
```bash
./scripts/deploy.sh multi status   # Show all teams
oc project team-ops && ./scripts/deploy.sh tools   # 3 tools
oc project team-hr && ./scripts/deploy.sh tools    # 8 tools
oc project team-dev && ./scripts/deploy.sh tools   # 17 tools
```

### Cleanup After Demo
```bash
./scripts/deploy.sh multi cleanup  # Remove team namespaces
```

### All Deploy Commands

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
| `./scripts/deploy.sh multi setup` | Create team namespaces |
| `./scripts/deploy.sh multi status` | Show all team status |
| `./scripts/deploy.sh multi cleanup` | Remove team namespaces |

---

## Backup & Recovery

### If Live Deploy Fails

Fall back to pre-setup environments:

```bash
# Skip to multi-project demo
oc project team-hr
./scripts/deploy.sh tools
```

**Say:** "Let me show you what it looks like when fully configured..."

### If Pod Takes Too Long

```bash
# Check pod status
oc get pods -n my-first-model | grep lsd

# If stuck, force restart
oc delete pod -l app=lsd-genai-playground -n my-first-model
```

### If Frontend Not Working

Use curl to show API directly:

```bash
# List tools via API
oc exec deployment/lsd-genai-playground -n my-first-model -- \
  curl -s http://localhost:8321/v1/tools | python3 -m json.tool
```

### If Network Issues

Have screenshots/recordings as backup.

---

## Available MCP Servers

| MCP Server | Toolgroup ID | Tools | Endpoint |
|------------|--------------|-------|----------|
| **Weather** | `mcp::weather-data` | getforecast | `http://mcp-weather...svc.cluster.local:80/sse` |
| **HR** | `mcp::hr-tools` | get_vacation_balance, get_employee_info, list_employees, list_job_openings, create_vacation_request | `http://hr-mcp-server...svc.cluster.local:8000/mcp` |
| **Jira/Confluence** | `mcp::jira-confluence` | search_issues, get_issue_details, create_issue, search_confluence, list_projects | `http://jira-mcp-server...svc.cluster.local:8000/mcp` |
| **GitHub** | `mcp::github-tools` | search_repositories, get_repository, list_issues, search_code, get_user | `http://github-mcp-server...svc.cluster.local:8000/mcp` |

### Team Configurations

| Team | Namespace | MCP Servers | Tools |
|------|-----------|-------------|-------|
| Ops | team-ops | Weather | 3 |
| HR | team-hr | Weather + HR | 8 |
| Dev | team-dev | Weather + HR + Jira + GitHub | 17 |

---

## YAML Reference

### The File to Edit

The LlamaStack configuration is stored in a ConfigMap:

```bash
oc get configmap llama-stack-config -n my-first-model -o yaml
```

### The Section to Edit: `tool_groups`

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
| `llama-stack-config-phase2.yaml` | Weather + HR | 8 |
| `llama-stack-config-full.yaml` | All 4 | 17 |

### Manual Config Switch (For Demo)

```bash
# Switch to Phase 2 (Weather + HR)
oc create configmap llama-stack-config \
  --from-file=run.yaml=manifests/llamastack/llama-stack-config-phase2.yaml \
  -n my-first-model --dry-run=client -o yaml | oc apply -f -

# Restart LlamaStack
oc delete pod -l app=lsd-genai-playground -n my-first-model
```

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

# Verify config has the MCP server
oc get configmap llama-stack-config -n my-first-model -o jsonpath='{.data.run\.yaml}' | grep -A4 "toolgroup_id: mcp::"
```

### Pod stuck in pending/crash

```bash
# Check pod events
oc describe pod -l app=lsd-genai-playground -n my-first-model | tail -20

# Check resources
oc get pods -n my-first-model -o wide
```

---

## Summary

### Before Demo
1. ✅ Run `./scripts/deploy.sh multi setup`
2. ✅ Run `./scripts/deploy.sh reset` in `my-first-model`
3. ✅ Verify frontend is accessible
4. ✅ Test demo scenarios

### During Demo
1. 🎯 Show live `add hr` deployment (8 min)
2. 🎯 Show multi-project comparison (8 min)
3. 🎯 Interactive frontend demo (10 min)

### Key Messages
- **YAML-based control** - Admins configure via ConfigMap
- **Role-based access** - Different teams get different tools
- **Easy to change** - Just update config and restart
- **Auditable** - All changes in version-controlled YAML
- **No code changes** - Users don't modify applications
