# LlamaStack Multi-MCP Demo

> **Enterprise AI Agent Platform with Multiple MCP Server Integrations**

A comprehensive demonstration of LlamaStack with multiple Model Context Protocol (MCP) servers, showing how to build enterprise AI agents with real-world tool integrations.

---

## 🎯 What This Demo Shows

1. **Multiple MCP Servers** - Weather, HR, Jira/Confluence, GitHub integrations
2. **Phase-based Deployment** - Start simple, add complexity progressively
3. **YAML-based Management** - Admin-controlled MCP server configuration
4. **User Tool Selection** - Users choose which tools to use
5. **Enterprise Patterns** - Separation of admin vs user capabilities

---

## 🚀 Quick Start

### Prerequisites
- OpenShift cluster with OpenShift AI
- `oc` CLI logged in
- LlamaStack distribution deployed
- Model serving endpoint (vLLM)

### Deploy Demo

```bash
# Clone the repository
git clone https://github.com/gymnatics/llamastack-demo.git
cd llamastack-demo

# Login and switch to your namespace
oc login --token=<token> --server=<url>
oc project my-demo

# Deploy Phase 1 (Weather MCP only)
./scripts/deploy.sh phase1

# Check status
./scripts/deploy.sh status

# Add HR MCP
./scripts/deploy.sh add-hr

# List available tools
./scripts/deploy.sh tools
```

---

## 📦 Available MCP Servers

| MCP Server | Tools | Description |
|------------|-------|-------------|
| **Weather (Simple)** | getforecast | OpenWeatherMap-based weather data |
| **Weather (MongoDB)** | search_weather, get_current_weather, list_stations, get_statistics | MongoDB-backed with rich queries |
| **HR** | get_vacation_balance, get_employee_info, list_employees, list_job_openings, create_vacation_request | Employee management |
| **Jira/Confluence** | search_issues, get_issue_details, create_issue, search_confluence, list_projects | Project management |
| **GitHub** | search_repositories, get_repository, list_issues, search_code, get_user | Code repository integration |

---

## 📁 Project Structure

```
llamastack-demo/
├── docs/
│   ├── DEMO-GUIDE.md           # Step-by-step demo instructions
│   ├── PRD.md                  # Product requirements
│   └── PROJECT-LOG.md          # Development log
├── manifests/
│   ├── phase1/                 # Weather only deployment
│   ├── phase2/                 # Weather + HR deployment
│   ├── full/                   # All 4 MCP servers
│   ├── llamastack/             # LlamaStack configurations
│   ├── mcp-servers/            # Individual MCP server manifests
│   │   ├── weather-mongodb/    # MongoDB Weather MCP
│   │   ├── hr-mcp-server.yaml
│   │   ├── jira-mcp-server.yaml
│   │   └── github-mcp-server.yaml
│   ├── frontend/               # Multi-MCP UI
│   └── namespaces/             # Namespace definitions
├── mcp/
│   └── weather-mongodb/        # MongoDB Weather MCP source
├── scripts/
│   └── deploy-demo.sh          # Main deployment script
└── README.md
```

---

## 🎮 Demo Script Commands

The script auto-detects your current namespace. Just switch to your namespace and run!

```bash
# Switch to your namespace
oc project my-demo

# Deploy commands
./scripts/deploy.sh phase1      # Deploy Weather MCP only
./scripts/deploy.sh phase2      # Deploy Weather + HR MCPs
./scripts/deploy.sh full        # Deploy all 4 MCP servers

# Manage MCP servers (without redeploying)
./scripts/deploy.sh add-hr      # Add HR MCP to existing setup
./scripts/deploy.sh add-all     # Add all MCPs to existing setup
./scripts/deploy.sh reset       # Reset to Weather only

# Info commands
./scripts/deploy.sh status      # Show pods and routes
./scripts/deploy.sh tools       # List available tools
./scripts/deploy.sh config      # Show current MCP config
```

---

## 🔧 How to Add an MCP Server

### 1. Edit LlamaStack ConfigMap

Add a new toolgroup entry:

```yaml
tool_groups:
- toolgroup_id: mcp::hr-tools
  provider_id: model-context-protocol
  mcp_endpoint:
    uri: http://hr-mcp-server.my-first-model.svc.cluster.local:8000/mcp
```

### 2. Apply and Restart

```bash
oc create configmap llama-stack-config \
  --from-file=run.yaml=your-config.yaml \
  -n my-first-model --dry-run=client -o yaml | oc apply -f -

oc delete pod -l app=lsd-genai-playground -n my-first-model
```

### 3. Verify

```bash
./scripts/deploy-demo.sh tools
```

---

## 🖥️ Frontend UI

The demo includes a Streamlit-based UI with:

- **Multi-MCP Support** - View and toggle multiple MCP servers
- **Tool Discovery** - See all available tools grouped by server
- **User Preferences** - Users can enable/disable servers
- **Admin Mode** - Admins can add/remove servers (set `ADMIN_MODE=true`)

### Deploy Frontend

```bash
oc apply -f manifests/frontend/deployment.yaml -n my-first-model
```

---

## 📊 Demo Scenarios

### Scenario 1: Weather Query
```
User: "What's the weather in Delhi?"
→ Uses Weather MCP → getforecast tool
```

### Scenario 2: HR Self-Service
```
User: "Check vacation balance for EMP001"
→ Uses HR MCP → get_vacation_balance tool
```

### Scenario 3: Developer Workflow
```
User: "Search for open bugs in the DEMO project"
→ Uses Jira MCP → search_issues tool
```

### Scenario 4: Multi-Tool Query
```
User: "Find popular Kubernetes repos and create a Jira ticket to evaluate them"
→ Uses GitHub MCP → search_repositories
→ Uses Jira MCP → create_issue
```

---

## 🔐 Admin vs User Capabilities

| Capability | User | Admin |
|------------|------|-------|
| View MCP servers | ✅ | ✅ |
| Toggle servers on/off | ✅ | ✅ |
| Use tools | ✅ | ✅ |
| Add new MCP server | ❌ | ✅ (via YAML) |
| Remove MCP server | ❌ | ✅ (via YAML) |

---

## 🐛 Troubleshooting

### MCP Server not connecting
```bash
# Check pod status
oc get pods -n my-first-model | grep mcp

# Check logs
oc logs deployment/hr-mcp-server -n my-first-model
```

### Tools not showing up
```bash
# Check LlamaStack logs
oc logs deployment/lsd-genai-playground -n my-first-model | grep -i error

# Verify config
oc get configmap llama-stack-config -n my-first-model -o yaml
```

### LlamaStack not picking up changes
```bash
# Force restart
oc delete pod -l app=lsd-genai-playground -n my-first-model
```

---

## 📚 References

- [LlamaStack Documentation](https://llama-stack.readthedocs.io/)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [FastMCP](https://github.com/jlowin/fastmcp)
- [OpenShift AI](https://docs.redhat.com/en/documentation/red_hat_openshift_ai)

---

## 📝 License

Apache License 2.0

---

## 👤 Author

**Danny Yeo**

---

⭐ Star this repo • 🐛 Report Issue • 🍴 Fork
