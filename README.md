# LlamaStack MCP Demo

A demonstration of LlamaStack orchestrating AI agents with Model Context Protocol (MCP) tools. This repo includes a Weather MCP Server, sample MongoDB data, and a Streamlit-based Demo UI.

![Architecture](https://img.shields.io/badge/LlamaStack-MCP-blue) ![OpenShift](https://img.shields.io/badge/OpenShift-Ready-red) ![License](https://img.shields.io/badge/License-Apache%202.0-green)

---

## 🏗️ Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   User      │────▶│  Demo UI    │────▶│ LlamaStack  │────▶│     LLM     │
│  (Browser)  │     │ (Streamlit) │     │(Orchestrator)│    │   (vLLM)    │
└─────────────┘     └─────────────┘     └──────┬──────┘     └─────────────┘
                                               │
                                               ▼
                                        ┌─────────────┐     ┌─────────────┐
                                        │ Weather MCP │────▶│   MongoDB   │
                                        │   Server    │     │  (Weather)  │
                                        └─────────────┘     └─────────────┘
```

---

## ✨ What's Included

- 🎨 **Demo UI** - Streamlit chatbot with real-time tool visualization
- 🌤️ **Weather MCP Server** - Sample MCP server with 5 weather tools
- 🗄️ **MongoDB** - Database with 14 global weather stations (48 hours of data each)

> **Note:** This repo deploys the demo components. You need an existing LlamaStack deployment.
> For full LlamaStack deployment with multi-provider support (vLLM, Azure, OpenAI, Ollama, Bedrock),
> use the [rhoai-toolkit.sh](https://github.com/gymnatics/openshift-installation).

---

## 🚀 Quick Start

### Prerequisites
- OpenShift cluster with RHOAI
- LlamaStack already deployed
- `oc` CLI installed and logged in

### One-Command Deploy

```bash
git clone https://github.com/gymnatics/llamastack-demo.git
cd llamastack-demo
./deploy.sh
```

The script offers 3 options:
1. **Complete Demo Stack** - UI + MCP + MongoDB (connects to existing LlamaStack)
2. **MCP + MongoDB only** - Just the backend
3. **UI only** - Just the frontend

---

## 📋 Deployment Options

### Option 1: Complete Demo Stack
Deploys everything needed to demo MCP with your existing LlamaStack:
- Weather MCP Server
- MongoDB with sample data
- Demo UI

You'll be prompted for your LlamaStack URL and Model ID.

### Option 2: MCP + MongoDB Only
Just the backend components. Use this if you want to integrate with your own frontend or test MCP directly.

### Option 3: UI Only
Just the Streamlit demo. Use this if you already have an MCP server running.

---

## 🔗 Register MCP with LlamaStack

After deploying the Weather MCP Server, you need to register it with your LlamaStack:

Add to your LlamaStack config under `tool_groups`:

```yaml
- toolgroup_id: mcp::weather-data
  provider_id: model-context-protocol
  mcp_endpoint:
    uri: http://weather-mcp-server.YOUR_NAMESPACE.svc.cluster.local:8000/mcp
```

Then restart LlamaStack to load the new tools.

---

## 📁 Project Structure

```
llamastack-demo/
├── deploy.sh               # Deployment script
├── README.md               # This file
├── app.py                  # Demo UI (Streamlit)
├── Dockerfile              # Demo UI container
├── deployment.yaml         # Demo UI manifests
├── buildconfig.yaml        # Demo UI build config
├── requirements.txt        # Python dependencies
└── mcp/                    # Weather MCP Server
    ├── http_app.py         # MCP server application
    ├── Dockerfile          # MCP container
    ├── deployment.yaml     # MCP manifests
    ├── buildconfig.yaml    # MCP build config
    ├── mongodb-deployment.yaml
    ├── init-data-job.yaml
    └── README.md
```

---

## 🌍 Included Weather Stations

| Code | City | Country |
|------|------|---------|
| VIDP | New Delhi | India |
| VABB | Mumbai | India |
| VOBL | Bangalore | India |
| VOMM | Chennai | India |
| VECC | Kolkata | India |
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

## 🔧 Weather MCP Tools

| Tool | Description |
|------|-------------|
| `search_weather` | Search observations with filters |
| `get_current_weather` | Get latest observation for a station |
| `list_stations` | List all available weather stations |
| `get_statistics` | Get database statistics |
| `health_check` | Check server and database health |

### Sample Queries
- "What's the weather in Delhi?"
- "Find airports with temperature above 30°C"
- "Which stations have fog right now?"
- "Compare weather in London and New York"

---

## 🛠️ Full LlamaStack Deployment

Need to deploy LlamaStack from scratch with provider selection?

Use the **rhoai-toolkit.sh** from the main repository:

```bash
git clone https://github.com/gymnatics/openshift-installation.git
cd openshift-installation
./rhoai-toolkit.sh
# Choose: RHOAI Management → Deploy LlamaStack Demo → Deploy Everything with LlamaStack
```

This gives you:
- LlamaStack deployment with provider selection (vLLM, Azure, OpenAI, Ollama, Bedrock)
- Automatic MCP registration
- Complete end-to-end demo

---

## ⚙️ Customization

### Different Namespace
The script handles namespace substitution automatically.

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

---

## 📝 License

Apache License 2.0

---

## 👤 Author

Danny Yeo

---

## 📖 Blog Guide

For a comprehensive technical guide with troubleshooting and lessons learned, see:

**[BLOG-GUIDE.md](./BLOG-GUIDE.md)** - Building an AI Agent with LlamaStack and MCP on OpenShift AI

---

## 🤝 Contributing

1. Fork this repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request
