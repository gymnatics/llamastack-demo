# LlamaStack MCP Demo

> **A complete guide to deploying an LLM-powered AI agent that can query external data sources using the Model Context Protocol (MCP).**

[![GitHub](https://img.shields.io/badge/GitHub-Repository-blue?logo=github)](https://github.com/gymnatics/llamastack-demo)
[![OpenShift](https://img.shields.io/badge/OpenShift-Ready-red?logo=redhatopenshift)](https://www.redhat.com/en/technologies/cloud-computing/openshift/openshift-ai)
[![License](https://img.shields.io/badge/License-Apache%202.0-green)](LICENSE)

---

## 📋 Table of Contents

- [Why I Built This](#-why-i-built-this)
- [Overview](#-overview)
- [Architecture](#-architecture)
- [Quick Start](#-quick-start)
- [Manual Deployment](#-manual-deployment)
- [Component Deep Dive](#-component-deep-dive)
- [Troubleshooting](#-troubleshooting)
- [Lessons Learned](#-lessons-learned)
- [Customization](#-customization)
- [References](#-references)

---

## 💡 Why I Built This

I created this project to solve a common challenge: **testing LlamaStack with different LLM providers through a visual interface**.

### The Problem

When working with LlamaStack and MCP, developers often need to:
- Test tool-calling capabilities across different LLM providers
- Validate MCP server integrations before production deployment
- Demo AI agent functionality to stakeholders
- Quickly prototype and iterate on agent workflows

Setting this up from scratch every time is tedious and error-prone.

### The Solution

This demo provides a **ready-to-deploy testing environment** with:
- A configurable UI that works with any LlamaStack deployment
- A sample MCP server (weather data) to test tool calling
- Support for multiple LLM providers out of the box
- Clear documentation of lessons learned and gotchas

### Who Is This For?

| Audience | Use Case |
|----------|----------|
| **Enterprise Teams** | Test LlamaStack on OpenShift AI with vLLM, Azure OpenAI, or other providers |
| **Open Source Users** | Run LlamaStack locally with Ollama or self-hosted models |
| **Developers** | Prototype MCP integrations and test tool-calling behavior |
| **Solution Architects** | Demo AI agent capabilities to customers |
| **Students/Learners** | Learn how LlamaStack, MCP, and tool-calling work together |

---

## 🎯 Overview

This guide documents how to build an AI agent that can:

| Capability | Description |
|------------|-------------|
| 💬 **Natural Language** | Accept queries from users in plain English |
| 🧠 **Tool Selection** | Automatically decide when to use external tools |
| 🔍 **Data Access** | Query real data from databases via MCP |
| 📝 **Response Synthesis** | Return human-readable, contextual responses |

### What's Included

- 🎨 **Demo UI** - Streamlit chatbot with real-time tool visualization
- 🌤️ **Weather MCP Server** - Sample MCP server with 5 weather tools
- 🗄️ **MongoDB** - Database with global weather stations

### Tech Stack

| Component | Technology |
|-----------|------------|
| **Platform** | OpenShift AI 3.0 / Kubernetes / Docker |
| **Orchestration** | LlamaStack |
| **LLM Providers** | vLLM, Azure OpenAI, OpenAI, Ollama, Bedrock |
| **MCP Framework** | FastMCP (Python) |
| **Database** | MongoDB |
| **Frontend** | Streamlit |

---

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                              Your Cluster                                │
│                                                                          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌────────┐ │
│  │   User UI    │───▶│  LlamaStack  │───▶│     LLM      │    │MongoDB │ │
│  │  (Streamlit) │    │ (Orchestrator)│    │  (Provider)  │    │        │ │
│  └──────────────┘    └──────┬───────┘    └──────────────┘    └────────┘ │
│                             │                                      ▲     │
│                             │                                      │     │
│                             ▼                                      │     │
│                      ┌──────────────┐                              │     │
│                      │  MCP Server  │──────────────────────────────┘     │
│                      │ (FastMCP)    │                                    │
│                      └──────────────┘                                    │
└──────────────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. 👤 User asks: *"What's the weather in Delhi?"*
2. 🔄 LlamaStack sends query + available tools to LLM
3. 🧠 LLM decides to call `search_weather` tool with `station: "VIDP"`
4. ⚡ LlamaStack invokes MCP server with tool call
5. 🗄️ MCP server queries MongoDB, returns weather data
6. 🔙 LlamaStack sends tool result back to LLM
7. ✍️ LLM generates human-readable response
8. 📱 UI displays response to user

### Supported LLM Providers

| Provider | Use Case |
|----------|----------|
| vLLM (RHOAI) | Models deployed on OpenShift AI |
| Azure OpenAI | GPT-4, GPT-4o |
| OpenAI | GPT-4, GPT-4o |
| Ollama | Local development |
| AWS Bedrock | Claude, Llama, Titan |

---

## 🚀 Quick Start

### Prerequisites

Choose your platform:

| Platform | Requirements |
|----------|--------------|
| **OpenShift** | OpenShift AI 3.0+, `oc` CLI, LlamaStack deployed |
| **Kubernetes** | Any K8s cluster, `kubectl`, container registry |
| **Docker** | Docker Desktop, Docker Compose |

### One-Command Deploy

```bash
git clone https://github.com/gymnatics/llamastack-demo.git
cd llamastack-demo
./deploy.sh
```

The script will ask you to select your platform:
1. **OpenShift** - Uses `oc`, BuildConfigs, Routes
2. **Kubernetes** - Uses `kubectl`, requires pre-built images
3. **Local Docker** - Uses `docker compose`, runs everything locally

Then offers deployment options:
- **Complete Demo Stack** - UI + MCP + MongoDB
- **MCP + MongoDB only** - Just the backend
- **UI only** - Just the frontend

---

## 📖 Manual Deployment

If you prefer not to use the deploy script:

### Path A: OpenShift

```bash
# Enable LlamaStack operator (if not already enabled)
oc get crd llamastackdistributions.llamastack.io || \
oc patch datasciencecluster default-dsc --type merge \
  -p '{"spec":{"components":{"llamastackoperator":{"managementState":"Managed"}}}}'

# Set namespace
export NAMESPACE=demo-test
oc project $NAMESPACE

# Deploy MongoDB
oc apply -f mcp/mongodb-deployment.yaml

# Initialize sample data
oc apply -f mcp/init-data-job.yaml

# Build and deploy MCP Server
oc apply -f mcp/buildconfig.yaml
oc start-build weather-mcp-server --from-dir=mcp --follow
oc apply -f mcp/deployment.yaml

# Build and deploy Demo UI
oc apply -f buildconfig.yaml
oc start-build llamastack-mcp-demo --from-dir=. --follow
oc apply -f deployment.yaml
```

### Path B: Local Docker / Open Source

```bash
# Step 1: Start MongoDB
docker run -d --name mongodb -p 27017:27017 mongo:6.0

# Step 2: Start the MCP Server
cd mcp
pip install mcp motor uvicorn
export MONGODB_URL="mongodb://localhost:27017"
python http_app.py
# Server runs on http://localhost:8000

# Step 3: Start LlamaStack with Ollama
ollama pull llama3.1:8b

cat > run.yaml << 'EOF'
version: 2
providers:
  inference:
  - provider_id: ollama
    provider_type: remote::ollama
    config:
      url: http://localhost:11434
  tool_runtime:
  - provider_id: mcp
    provider_type: remote::model-context-protocol
    config: {}

tool_groups:
- toolgroup_id: mcp::weather
  provider_id: mcp
  mcp_endpoint:
    uri: http://localhost:8000/mcp

models:
- model_id: llama3.1:8b
  provider_id: ollama
  provider_model_id: llama3.1:8b
EOF

llama stack run run.yaml --port 8321

# Step 4: Start the Demo UI
cd ..
pip install -r requirements.txt
export LLAMASTACK_URL="http://localhost:8321"
export MODEL_ID="llama3.1:8b"
export MCP_SERVER_URL="http://localhost:8000"
streamlit run app.py
# UI available at http://localhost:8501
```

### Path C: Vanilla Kubernetes

```bash
# Build images locally first
docker build -t weather-mcp-server:latest ./mcp
docker build -t llamastack-mcp-demo:latest .

# Push to your registry
docker tag weather-mcp-server:latest your-registry/weather-mcp-server:latest
docker tag llamastack-mcp-demo:latest your-registry/llamastack-mcp-demo:latest
docker push your-registry/weather-mcp-server:latest
docker push your-registry/llamastack-mcp-demo:latest

# Update image references in deployment.yaml files, then:
kubectl apply -f mcp/mongodb-deployment.yaml
kubectl apply -f mcp/deployment.yaml
kubectl apply -f deployment.yaml
```

### About the Dockerfiles

This repo includes **two Dockerfiles per component**:

| File | Base Image | Use Case |
|------|------------|----------|
| `Dockerfile` | `python:3.12-slim` | Kubernetes, Docker, local dev |
| `Dockerfile.openshift` | `registry.redhat.io/ubi9/python-312` | OpenShift |

- **OpenShift BuildConfigs** automatically use `Dockerfile.openshift`
- **Kubernetes/Docker** deployments use the default `Dockerfile`

---

## 🔧 Component Deep Dive

### MCP Server

The MCP (Model Context Protocol) server exposes your data as tools that LLMs can use.

**Key Implementation** (`mcp/http_app.py`):

```python
from mcp.server.fastmcp import FastMCP
from mcp.server.transport_security import TransportSecuritySettings
from motor.motor_asyncio import AsyncIOMotorClient

# CRITICAL: Disable DNS rebinding protection for Kubernetes
transport_security = TransportSecuritySettings(
    enable_dns_rebinding_protection=False
)

mcp = FastMCP("weather-data", transport_security=transport_security)

@mcp.tool()
async def search_weather(
    station: str = None,
    location: str = None,
    min_temperature: float = None,
    conditions: str = None,
    limit: int = 10
) -> str:
    """Search for weather observations with optional filters."""
    # Query MongoDB and return formatted results
    ...

@mcp.tool()
async def get_current_weather(station: str) -> str:
    """Get the most recent weather observation for a station."""
    ...

if __name__ == "__main__":
    import uvicorn
    app = mcp.streamable_http_app()
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

**Available Tools:**

| Tool | Description |
|------|-------------|
| `search_weather` | Search with filters (station, location, temperature, conditions) |
| `get_current_weather` | Get latest observation for a specific station |
| `list_stations` | List all available weather stations |
| `get_statistics` | Get database statistics and coverage |
| `health_check` | Check server and database health |

### LLM with Tool Calling

Not all LLMs support tool calling. Here's what works:

| Model | Provider | Tool Parser |
|-------|----------|-------------|
| Qwen3-8B | vLLM | `hermes` |
| Llama 3.1+ | vLLM | `llama3_json` |
| Mistral | vLLM | `mistral` |
| GPT-4o | Azure/OpenAI | Native |
| Claude 3 | Bedrock | Native |

**vLLM Configuration** - Required args for tool calling:

```yaml
args:
  - --enable-auto-tool-choice        # REQUIRED
  - --tool-call-parser=hermes        # REQUIRED (use correct parser)
```

### LlamaStack Configuration

Register MCP with LlamaStack by adding to `tool_groups`:

```yaml
tool_groups:
- toolgroup_id: mcp::weather-data
  provider_id: model-context-protocol
  mcp_endpoint:
    uri: http://weather-mcp-server.NAMESPACE.svc.cluster.local:8000/mcp
```

**Verify tools are registered:**

```bash
curl -s http://llamastack-service:8321/v1/tools | jq '.data[].name'
# Expected: "search_weather", "get_current_weather", "list_stations", etc.
```

### Demo UI Configuration

| Variable | Description |
|----------|-------------|
| `LLAMASTACK_URL` | LlamaStack service endpoint |
| `MODEL_ID` | Model ID registered in LlamaStack |
| `MCP_SERVER_URL` | MCP server URL |
| `APP_TITLE` | Page title |
| `MCP_SERVER_NAME` | Name in architecture diagram |

---

## 🔥 Troubleshooting

### HTTP 421: Invalid Host header

**Cause**: MCP SDK's DNS rebinding protection rejects Kubernetes service hostnames.

**Fix**:
```python
from mcp.server.transport_security import TransportSecuritySettings

transport_security = TransportSecuritySettings(enable_dns_rebinding_protection=False)
mcp = FastMCP("weather-data", transport_security=transport_security)
```

### Model doesn't call tools

**Cause**: vLLM not configured for tool calling.

**Fix**: Add to ServingRuntime args:
```yaml
- --enable-auto-tool-choice
- --tool-call-parser=hermes
```

### No tools found (only RAG tools showing)

**Cause**: MCP server not registered in LlamaStack config.

**Fix**: Add toolgroup to LlamaStack ConfigMap:
```yaml
tool_groups:
- toolgroup_id: mcp::weather-data
  provider_id: model-context-protocol
  mcp_endpoint:
    uri: http://weather-mcp-server:8000/mcp
```

### MCP Server pod not ready

**Cause**: HTTP health probes fail (MCP has no `/health` endpoint).

**Fix**: Use TCP probes:
```yaml
readinessProbe:
  tcpSocket:
    port: 8000
```

### MongoDB image pull error

**Fix**: Use full image path:
```yaml
image: docker.io/library/mongo:6.0
```

### Service name resolution fails

**Cause**: Wrong service name in configuration.

**Fix**: Check actual service name with `oc get svc` or `kubectl get svc`. OpenShift AI often adds `-service` suffix.

---

## 💡 Lessons Learned

| # | Lesson |
|---|--------|
| 1 | **DNS rebinding protection** must be disabled for Kubernetes deployments |
| 2 | **Tool calling** requires explicit vLLM configuration (`--enable-auto-tool-choice`) |
| 3 | **Multiple ConfigMaps** may exist - verify which one is actually mounted |
| 4 | **Service names** may not match deployment names (check with `get svc`) |
| 5 | **MCP responses** are nested structures - parse carefully |
| 6 | **TCP probes** work better than HTTP for MCP servers |
| 7 | **End-to-end testing** is essential - each component may work alone but fail when connected |

---

## ⚙️ Customization

### Custom Branding

Update `deployment.yaml` ConfigMap:
```yaml
data:
  APP_TITLE: "Your Company AI Assistant"
  APP_SUBTITLE: "Powered by LlamaStack"
  MCP_SERVER_NAME: "Your Data API"
```

### Your Own Data

1. Modify `mcp/init-data-job.yaml` with your data
2. Update `mcp/http_app.py` with your tools
3. Rebuild: `oc start-build weather-mcp-server --from-dir=mcp --follow`

### Full LlamaStack Deployment

Need to deploy LlamaStack from scratch with provider selection?

```bash
git clone https://github.com/gymnatics/openshift-installation.git
cd openshift-installation
./rhoai-toolkit.sh
# Choose: RHOAI Management → Deploy LlamaStack Demo → Deploy Everything with LlamaStack
```

---

## 📁 Project Structure

```
llamastack-demo/
├── deploy.sh                 # Universal deployment script (OpenShift/K8s/Docker)
├── README.md                 # This file
├── docker-compose.yaml       # Docker Compose config (auto-generated)
├── app.py                    # Demo UI (Streamlit)
├── Dockerfile                # Demo UI - Kubernetes/Docker
├── Dockerfile.openshift      # Demo UI - OpenShift
├── deployment.yaml           # Demo UI K8s manifests
├── buildconfig.yaml          # Demo UI OpenShift build config
├── requirements.txt          # Python dependencies
└── mcp/                      # Weather MCP Server
    ├── http_app.py           # MCP server application
    ├── sample_data.py        # Sample data generator
    ├── Dockerfile            # MCP - Kubernetes/Docker
    ├── Dockerfile.openshift  # MCP - OpenShift
    ├── deployment.yaml       # MCP K8s manifests
    ├── buildconfig.yaml      # MCP OpenShift build config
    ├── mongodb-deployment.yaml
    ├── init-data-job.yaml
    └── README.md
```

---

## 🌍 Sample Weather Stations

| Code | City | Country |
|------|------|---------|
| VIDP | New Delhi | India |
| VABB | Mumbai | India |
| WSSS | Singapore | Singapore |
| VHHH | Hong Kong | China |
| RJTT | Tokyo | Japan |
| EGLL | London | UK |
| LFPG | Paris | France |
| KJFK | New York | USA |
| KLAX | Los Angeles | USA |
| OMDB | Dubai | UAE |
| YSSY | Sydney | Australia |

---

## 💬 Example Queries

Try asking:
- *"What's the current weather in Delhi?"*
- *"Find all stations with temperature above 30°C"*
- *"Which airports have fog right now?"*
- *"Compare the weather in London and New York"*

---

## 📚 References

- [Model Context Protocol (MCP)](https://modelcontextprotocol.io/)
- [LlamaStack](https://github.com/meta-llama/llama-stack)
- [vLLM Tool Calling](https://docs.vllm.ai/en/latest/features/tool_calling.html)
- [FastMCP](https://github.com/jlowin/fastmcp)
- [OpenShift AI](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/)

---

## 📝 License

Apache License 2.0

---

## 👤 Author

**Danny Yeo**

---

## 🤝 Contributing

1. Fork this repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

---

<p align="center">
  <a href="https://github.com/gymnatics/llamastack-demo">⭐ Star this repo</a> •
  <a href="https://github.com/gymnatics/llamastack-demo/issues">🐛 Report Issue</a> •
  <a href="https://github.com/gymnatics/llamastack-demo/fork">🍴 Fork</a>
</p>
