---
layout: default
title: Building an AI Agent with LlamaStack and MCP on OpenShift AI
---

# Building an AI Agent with LlamaStack and MCP on OpenShift AI

> **A complete guide to deploying an LLM-powered AI agent that can query external data sources using the Model Context Protocol (MCP).**

[![GitHub](https://img.shields.io/badge/GitHub-Repository-blue?logo=github)](https://github.com/gymnatics/llamastack-demo)
[![OpenShift](https://img.shields.io/badge/OpenShift-Ready-red?logo=redhatopenshift)](https://www.redhat.com/en/technologies/cloud-computing/openshift/openshift-ai)
[![License](https://img.shields.io/badge/License-Apache%202.0-green)](LICENSE)

---

## 📋 Table of Contents

- [Why I Built This](#-why-i-built-this)
- [Overview](#-overview)
- [Architecture](#-architecture)
- [Prerequisites](#-prerequisites)
- [Quick Start](#-quick-start)
- [Component 1: MCP Server](#-component-1-mcp-server)
- [Component 2: LLM with Tool Calling](#-component-2-llm-with-tool-calling)
- [Component 3: LlamaStack Orchestration](#-component-3-llamastack-orchestration)
- [Component 4: Demo UI](#-component-4-demo-ui)
- [Troubleshooting](#-troubleshooting)
- [Lessons Learned](#-lessons-learned)

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

### Works With

This demo is designed to work with:

- **OpenShift AI** - Full enterprise deployment with LlamaStack operator
- **Open Source LlamaStack** - Run anywhere with `llama stack run`
- **Local Development** - Test with Ollama + local LlamaStack
- **Cloud Providers** - Connect to Azure OpenAI, OpenAI, AWS Bedrock

---

## 🎯 Overview

This guide documents how to build an AI agent that can:

| Capability | Description |
|------------|-------------|
| 💬 **Natural Language** | Accept queries from users in plain English |
| 🧠 **Tool Selection** | Automatically decide when to use external tools |
| 🔍 **Data Access** | Query real data from databases via MCP |
| 📝 **Response Synthesis** | Return human-readable, contextual responses |

### Use Case

**Weather Data Queries** - Users can ask *"What's the weather in Delhi?"* and the system fetches live data from MongoDB.

### Tech Stack

| Component | Technology |
|-----------|------------|
| **Platform** | OpenShift AI 3.0 |
| **Orchestration** | LlamaStack |
| **LLM Providers** | vLLM, Azure OpenAI, OpenAI, Ollama, Bedrock |
| **MCP Framework** | FastMCP (Python) |
| **Database** | MongoDB |
| **Frontend** | Streamlit |

---

## 🏗 Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           OpenShift Cluster                              │
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

---

## ✅ Prerequisites

Before you begin, ensure you have:

- [ ] OpenShift cluster with **OpenShift AI 3.0+** installed
- [ ] LlamaStack operator enabled
- [ ] `oc` CLI configured and logged in
- [ ] Access to an LLM (vLLM, Azure OpenAI, OpenAI, etc.)

### Enabling LlamaStack

```bash
# Check if LlamaStack CRD exists
oc get crd llamastackdistributions.llamastack.io

# If not found, enable it:
oc patch datasciencecluster default-dsc --type merge \
  -p '{"spec":{"components":{"llamastackoperator":{"managementState":"Managed"}}}}'

# Wait for CRD to be available (~2-3 minutes)
```

---

## 🚀 Quick Start

### Option 1: Automated Deployment

```bash
git clone https://github.com/gymnatics/llamastack-demo.git
cd llamastack-demo
./deploy.sh
```

The script deploys:
1. ✅ MongoDB with sample weather data
2. ✅ Weather MCP Server
3. ✅ Demo UI

### Option 2: Manual Deployment

```bash
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

---

## 🔧 Component 1: MCP Server

The **Model Context Protocol (MCP)** server exposes your data/APIs as tools that LLMs can use.

### Implementation

```python
from mcp.server.fastmcp import FastMCP
from mcp.server.transport_security import TransportSecuritySettings
from motor.motor_asyncio import AsyncIOMotorClient
import os

# Configuration from environment
SERVER_NAME = os.getenv("MCP_SERVER_NAME", "weather-data")
MONGODB_URL = os.getenv("MONGODB_URL", "mongodb://mongodb:27017")

# CRITICAL: Disable DNS rebinding protection for Kubernetes
transport_security = TransportSecuritySettings(
    enable_dns_rebinding_protection=False
)

mcp = FastMCP(SERVER_NAME, transport_security=transport_security)

@mcp.tool()
async def search_weather(
    station: str = None,
    location: str = None,
    min_temperature: float = None,
    max_temperature: float = None,
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

@mcp.tool()
async def list_stations() -> str:
    """List all available weather stations."""
    ...

if __name__ == "__main__":
    import uvicorn
    app = mcp.streamable_http_app()
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

### Available Tools

| Tool | Description |
|------|-------------|
| `search_weather` | Search with filters (station, location, temperature, conditions) |
| `get_current_weather` | Get latest observation for a specific station |
| `list_stations` | List all available weather stations |
| `get_statistics` | Get database statistics and coverage |
| `health_check` | Check server and database health |

### ⚠️ Critical: DNS Rebinding Protection

**Problem**: In Kubernetes, requests come with `Host: weather-mcp-server.demo-test.svc.cluster.local`. The MCP SDK rejects this by default.

**Error**:
```
HTTP 421: Invalid Host header
```

**Solution**:
```python
transport_security = TransportSecuritySettings(
    enable_dns_rebinding_protection=False
)
mcp = FastMCP("weather-data", transport_security=transport_security)
```

---

## 🤖 Component 2: LLM with Tool Calling

Not all LLMs support tool calling. Here's what works:

### Supported Models

| Model | Provider | Tool Parser |
|-------|----------|-------------|
| Qwen3-8B | vLLM | `hermes` |
| Llama 3.1+ | vLLM | `llama3_json` |
| Mistral | vLLM | `mistral` |
| GPT-4o | Azure/OpenAI | Native |
| Claude 3 | Bedrock | Native |

### vLLM Configuration

**Required** arguments for tool calling:

```yaml
args:
  - --enable-auto-tool-choice        # REQUIRED
  - --tool-call-parser=hermes        # REQUIRED (use correct parser)
```

---

## 🔗 Component 3: LlamaStack Orchestration

LlamaStack manages tool registration and execution.

### Registering MCP with LlamaStack

Add to your LlamaStack ConfigMap under `tool_groups`:

```yaml
tool_groups:
- toolgroup_id: mcp::weather-data
  provider_id: model-context-protocol
  mcp_endpoint:
    uri: http://weather-mcp-server.NAMESPACE.svc.cluster.local:8000/mcp
```

### Verify Tools

```bash
curl -s http://llamastack-service:8321/v1/tools | jq '.data[].name'

# Expected:
"search_weather"
"get_current_weather"
"list_stations"
"get_statistics"
"health_check"
```

---

## 🎨 Component 4: Demo UI

A configurable Streamlit app for demonstrations.

### Configuration

| Variable | Description |
|----------|-------------|
| `LLAMASTACK_URL` | LlamaStack service endpoint |
| `MODEL_ID` | Model ID registered in LlamaStack |
| `MCP_SERVER_URL` | MCP server URL |
| `APP_TITLE` | Page title |
| `MCP_SERVER_NAME` | Name in architecture diagram |

---

## 🔥 Troubleshooting

### Model doesn't call tools

**Cause**: vLLM not configured for tool calling.

**Fix**:
```yaml
args:
  - --enable-auto-tool-choice
  - --tool-call-parser=hermes
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

---

## 💡 Lessons Learned

| # | Lesson |
|---|--------|
| 1 | **DNS rebinding protection** must be disabled for Kubernetes |
| 2 | **Tool calling** requires explicit vLLM configuration |
| 3 | **Multiple ConfigMaps** exist - verify which one is mounted |
| 4 | **Service names** may not match deployment names |
| 5 | **MCP responses** are nested - parse carefully |
| 6 | **TCP probes** work better than HTTP for MCP servers |
| 7 | **End-to-end testing** is essential |

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

<p align="center">
  <strong>Author:</strong> Danny Yeo<br>
  <strong>Last Updated:</strong> January 2026
</p>

<p align="center">
  <a href="https://github.com/gymnatics/llamastack-demo">⭐ Star this repo</a> •
  <a href="https://github.com/gymnatics/llamastack-demo/issues">🐛 Report Issue</a> •
  <a href="https://github.com/gymnatics/llamastack-demo/fork">🍴 Fork</a>
</p>

