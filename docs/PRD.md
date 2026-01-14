# Product Requirements Document (PRD)
# LlamaStack MCP Demo - Multi-Server AI Agent Platform

**Version:** 1.0  
**Date:** January 14, 2026  
**Author:** AI Platform Team  
**Status:** In Development

---

## Executive Summary

This document outlines the requirements for deploying a comprehensive LlamaStack MCP (Model Context Protocol) demonstration on Red Hat OpenShift AI. The demo showcases how AI agents can leverage multiple external tools through MCP servers, enabling enterprise-grade AI applications with real-world integrations.

---

## 1. Project Overview

### 1.1 Objective
Deploy a fully functional LlamaStack distribution with 4 MCP servers, demonstrating:
- Multi-tool AI agent orchestration
- Dynamic MCP server management
- Enterprise-relevant integrations (Weather, GitHub, HR, Jira/Confluence)
- Interactive playground for testing
- Sample application development patterns

### 1.2 Current State (Updated)
| Component | Status | Namespace |
|-----------|--------|-----------|
| LlamaStack Distribution | ✅ Running | `my-first-model` |
| Llama 3.2-3B Model | ✅ Running | `my-first-model` |
| Weather MCP Server | ✅ Running | `my-first-model` |
| GitHub MCP Server | ✅ Running | `my-first-model` |
| HR MCP Server | ✅ Running | `my-first-model` |
| Jira/Confluence MCP Server | ✅ Running | `my-first-model` |
| Enhanced Frontend | ✅ Deployed | `my-first-model` |

### 1.3 Target State - ACHIEVED ✅
- ✅ 4 MCP servers fully operational and registered (23 tools)
- ✅ Enhanced frontend with multi-MCP support
- ✅ Dynamic MCP server add/remove capability (via `deploy.sh add <mcp>`)
- ❌ Sample application (cancelled - frontend serves this purpose)
- ✅ Complete documentation and demo guide

---

## 2. Requirements

### 2.1 MCP Server Requirements

#### 2.1.1 Weather MCP Server (Existing - Colleague's Version)
- **Status:** ✅ Already deployed
- **Namespace:** `my-first-model`
- **Service:** `mcp-weather:3001` (Note: Port 3001, not 80)
- **Image:** `quay.io/rh-aiservices-bu/mcp-weather:0.1.0-amd64`
- **Tools:**
  - `getforecast` - Get weather forecast for a location
  - `get_current_weather` - Get current weather conditions
- **Data Source:** OpenWeatherMap API (demo mode)
- **Note:** This is NOT the MongoDB-based weather MCP from the toolkit. It's a colleague's implementation using OpenWeatherMap.

#### 2.1.2 GitHub MCP Server (Existing)
- **Status:** ✅ Configured as external
- **URL:** `https://api.githubcopilot.com/mcp`
- **Tools:**
  - Repository search and browsing
  - Issue management
  - Pull request operations
  - Code search
- **Authentication:** GitHub Personal Access Token

#### 2.1.3 HR MCP Server (New - To Deploy)
- **Source:** https://github.com/rh-ai-quickstart/llama-stack-mcp-server
- **Namespace:** `my-first-model`
- **Components:**
  - HR Enterprise API (FastAPI backend)
  - Custom MCP Server (SSE transport)
- **Tools:**
  - `get_vacation_balance` - Check employee vacation balances
  - `create_vacation_request` - Submit vacation requests
  - `get_employee_info` - Retrieve employee information
  - `list_job_openings` - List available positions
  - `get_performance_review` - Access performance data
- **Data Source:** In-memory/SQLite HR database

#### 2.1.4 Jira/Confluence MCP Server (New - To Create)
- **Purpose:** App dev team project management integration
- **Namespace:** `my-first-model`
- **Tools:**
  - `search_issues` - Search Jira issues
  - `create_issue` - Create new Jira tickets
  - `get_issue_details` - Get issue information
  - `search_confluence` - Search documentation
  - `get_page_content` - Retrieve Confluence pages
- **Note:** Will use mock data for demo purposes (no external Jira/Confluence required)

### 2.2 AI Asset Registration Requirements

All MCP servers must be registered in the `gen-ai-aa-mcp-servers` ConfigMap in `redhat-ods-applications` namespace:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: gen-ai-aa-mcp-servers
  namespace: redhat-ods-applications
data:
  Weather-MCP-Server: |
    {
      "url": "http://mcp-weather.my-first-model.svc.cluster.local:80/sse",
      "description": "Weather data MCP server with real-time observations",
      "transport": "sse"
    }
  GitHub-MCP-Server: |
    {
      "url": "https://api.githubcopilot.com/mcp",
      "description": "GitHub integration for repository and code operations"
    }
  HR-MCP-Server: |
    {
      "url": "http://hr-mcp-server.my-first-model.svc.cluster.local:8000/sse",
      "description": "HR system integration for employee and vacation management",
      "transport": "sse"
    }
  Jira-Confluence-MCP-Server: |
    {
      "url": "http://jira-mcp-server.my-first-model.svc.cluster.local:8000/sse",
      "description": "Project management integration for issues and documentation",
      "transport": "sse"
    }
```

### 2.3 LlamaStack Distribution Requirements

Update `llama-stack-config` ConfigMap to include MCP toolgroups:

```yaml
tool_groups:
- toolgroup_id: builtin::rag
  provider_id: rag-runtime
- toolgroup_id: mcp::weather-data
  provider_id: model-context-protocol
  mcp_endpoint:
    uri: http://mcp-weather.my-first-model.svc.cluster.local:80/sse
- toolgroup_id: mcp::hr-tools
  provider_id: model-context-protocol
  mcp_endpoint:
    uri: http://hr-mcp-server.my-first-model.svc.cluster.local:8000/sse
- toolgroup_id: mcp::jira-confluence
  provider_id: model-context-protocol
  mcp_endpoint:
    uri: http://jira-mcp-server.my-first-model.svc.cluster.local:8000/sse
```

### 2.4 Frontend Requirements

#### 2.4.1 Multi-MCP Server Support
- Display all registered MCP servers in sidebar
- Show connection status for each server
- Allow selecting which MCP servers to use per session
- Display tools from all selected MCP servers

#### 2.4.2 Dynamic MCP Management
- Add new MCP server via UI form
- Remove MCP server from active session
- Toggle MCP servers on/off without restart
- Persist MCP server preferences

#### 2.4.3 Architecture Visualization
- Show all connected MCP servers in flow diagram
- Real-time tool call visualization
- Per-server metrics (calls, latency)

### 2.5 Sample Application Requirements

Create a Python application demonstrating:
- LlamaStack API client usage
- Multi-tool agent conversations
- Error handling and retries
- Streaming responses
- Tool result processing

---

## 3. Technical Architecture

### 3.1 Component Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           OpenShift AI Cluster                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐         │
│  │   Frontend UI   │───▶│   LlamaStack    │───▶│  Llama 3.2-3B   │         │
│  │   (Streamlit)   │    │  Distribution   │    │    (vLLM)       │         │
│  └─────────────────┘    └────────┬────────┘    └─────────────────┘         │
│                                  │                                          │
│                    ┌─────────────┼─────────────┐                           │
│                    │             │             │                           │
│                    ▼             ▼             ▼                           │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐            │
│  │  Weather MCP    │  │    HR MCP       │  │  Jira MCP       │            │
│  │    Server       │  │    Server       │  │    Server       │            │
│  └────────┬────────┘  └────────┬────────┘  └────────┬────────┘            │
│           │                    │                    │                      │
│           ▼                    ▼                    ▼                      │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐            │
│  │    MongoDB      │  │   HR API        │  │  Mock Jira DB   │            │
│  │  (Weather Data) │  │  (Employee DB)  │  │  (Issues/Docs)  │            │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘            │
│                                                                              │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                    External MCP Server                               │   │
│  │  ┌─────────────────┐                                                │   │
│  │  │  GitHub MCP     │◀──── api.githubcopilot.com                     │   │
│  │  │    Server       │                                                │   │
│  │  └─────────────────┘                                                │   │
│  └─────────────────────────────────────────────────────────────────────┘   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 3.2 Data Flow

1. **User Query** → Frontend UI
2. **Frontend** → LlamaStack Distribution (OpenAI-compatible API)
3. **LlamaStack** → LLM (Llama 3.2-3B) for intent understanding
4. **LLM** → Returns tool call decision
5. **LlamaStack** → Routes to appropriate MCP Server
6. **MCP Server** → Executes tool, returns result
7. **LlamaStack** → Sends result back to LLM
8. **LLM** → Generates final response
9. **LlamaStack** → Frontend → User

### 3.3 Network Configuration

| Service | Port | Protocol | Endpoint |
|---------|------|----------|----------|
| LlamaStack | 8321 | HTTP | `/v1/openai/v1/chat/completions` |
| Weather MCP | 80 | HTTP/SSE | `/sse`, `/mcp` |
| HR MCP | 8000 | HTTP/SSE | `/sse` |
| Jira MCP | 8000 | HTTP/SSE | `/sse` |
| HR API | 8080 | HTTP | `/api/v1/*` |
| Frontend | 8501 | HTTP | `/` |

---

## 4. Deployment Plan

### Phase 1: MCP Server Deployment (Day 1)
1. Deploy HR MCP Server + HR API
2. Deploy Jira/Confluence MCP Server
3. Verify all MCP servers are healthy

### Phase 2: Integration (Day 1)
1. Update `gen-ai-aa-mcp-servers` ConfigMap
2. Update `llama-stack-config` with toolgroups
3. Restart LlamaStack distribution
4. Verify tools are discoverable

### Phase 3: Frontend Enhancement (Day 1-2)
1. Update frontend to support multiple MCP servers
2. Add dynamic MCP management UI
3. Deploy enhanced frontend
4. Test end-to-end flow

### Phase 4: Sample Application (Day 2)
1. Create sample Python application
2. Document API usage patterns
3. Create demo scenarios

### Phase 5: Documentation (Day 2)
1. Create deployment guide
2. Create demo script
3. Create troubleshooting guide

---

## 5. Demo Scenarios

### Scenario 1: Weather Assistant
```
User: "What's the weather like at major airports today?"
Agent: Uses weather MCP to query multiple stations
```

### Scenario 2: HR Self-Service
```
User: "Check my vacation balance and book next Friday off"
Agent: Uses HR MCP to check balance and create request
```

### Scenario 3: Developer Workflow
```
User: "Create a Jira ticket for the login bug and find related documentation"
Agent: Uses Jira MCP to create issue and search Confluence
```

### Scenario 4: Multi-Tool Query
```
User: "I need to plan a team offsite. Check everyone's vacation schedules, 
       find a location with good weather, and create a project ticket"
Agent: Uses HR MCP + Weather MCP + Jira MCP together
```

---

## 6. Success Criteria

| Criteria | Target | Actual | Status |
|----------|--------|--------|--------|
| MCP Servers Deployed | 4 | 4 | ✅ |
| Tools Discoverable | 15+ | 23 | ✅ |
| Frontend Functional | Yes | Yes | ✅ |
| Demo Scenarios | 4 | 5 | ✅ |
| Documentation | Complete | Complete | ✅ |

---

## 7. Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| MCP server connectivity issues | High | Use internal K8s DNS, health checks |
| LlamaStack config sync | Medium | Restart pods after config changes |
| Tool call failures | Medium | Implement retry logic, error handling |
| Resource constraints | Low | Monitor GPU/memory usage |

---

## 8. File Structure (Actual)

```
/Users/dayeo/LlamaStack-MCP-Demo/
├── docs/
│   ├── PRD.md                          # This document
│   ├── DEMO-GUIDE.md                   # Demo walkthrough & deployment guide
│   └── PROJECT-LOG.md                  # Development history
├── manifests/
│   ├── mcp-servers/
│   │   ├── hr-mcp-server.yaml          # HR MCP deployment
│   │   ├── hr-api.yaml                 # HR API backend
│   │   ├── jira-mcp-server.yaml        # Jira/Confluence MCP
│   │   ├── github-mcp-server.yaml      # GitHub MCP
│   │   └── weather-mongodb/            # MongoDB Weather MCP (optional)
│   ├── llamastack/
│   │   ├── llama-stack-config-phase1.yaml  # Weather only
│   │   ├── llama-stack-config-phase2.yaml  # Weather + HR
│   │   └── llama-stack-config-full.yaml    # All 4 MCPs
│   ├── frontend/
│   │   ├── app.py                      # Enhanced Streamlit app
│   │   └── deployment.yaml             # Frontend deployment
│   ├── phase1/                         # Phase 1 deployment bundle
│   ├── phase2/                         # Phase 2 deployment bundle
│   └── full/                           # Full deployment bundle
├── scripts/
│   ├── deploy.sh                       # Main deployment script
│   ├── validate-repo.sh                # Repository validation
│   └── test-deployment.sh              # Deployment testing
├── mcp/
│   └── weather-mongodb/                # MongoDB Weather MCP source
└── README.md                           # Project overview
```

---

## 9. Timeline

| Day | Tasks |
|-----|-------|
| Day 1 AM | Deploy HR MCP Server, Deploy Jira MCP Server |
| Day 1 PM | Register AI Assets, Update LlamaStack config |
| Day 2 AM | Enhance frontend, Deploy updated UI |
| Day 2 PM | Create sample app, Documentation |

---

## 10. Appendix

### A. API Endpoints

**LlamaStack OpenAI-Compatible API:**
```bash
POST /v1/openai/v1/chat/completions
GET /v1/tools
GET /v1/health
POST /v1/tool-runtime/invoke
```

**MCP Server Endpoints:**
```bash
POST /mcp          # JSON-RPC endpoint
GET /sse           # Server-Sent Events
GET /health        # Health check
```

### B. Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `LLAMASTACK_URL` | LlamaStack service URL | `http://localhost:8321` |
| `MODEL_ID` | Model identifier | `llama-32-3b-instruct` |
| `MCP_SERVER_URL` | Primary MCP server | - |

### C. References

- [LlamaStack Documentation](https://llama-stack.readthedocs.io/)
- [Model Context Protocol Spec](https://modelcontextprotocol.io/)
- [rh-ai-quickstart/llama-stack-mcp-server](https://github.com/rh-ai-quickstart/llama-stack-mcp-server)
- [Red Hat OpenShift AI Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai)
