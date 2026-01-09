# Building an AI Agent with LlamaStack and MCP on OpenShift AI

> A complete guide to deploying an LLM-powered AI agent that can query external data sources using the Model Context Protocol (MCP).

**Repository**: https://github.com/gymnatics/llamastack-demo

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Quick Start](#quick-start)
5. [Component 1: MCP Server](#component-1-mcp-server)
6. [Component 2: LLM with Tool Calling](#component-2-llm-with-tool-calling)
7. [Component 3: LlamaStack Orchestration](#component-3-llamastack-orchestration)
8. [Component 4: Demo UI](#component-4-demo-ui)
9. [Connecting the Components](#connecting-the-components)
10. [Troubleshooting](#troubleshooting)
11. [Lessons Learned](#lessons-learned)

---

## Overview

This guide documents how to build an AI agent that can:
- Accept natural language queries from users
- Automatically decide when to use external tools
- Query real data from databases via MCP (Model Context Protocol)
- Return synthesized, human-readable responses

**Use Case**: Weather data queries - users can ask "What's the weather in Delhi?" and the system fetches data from MongoDB.

**Tech Stack**:
- **OpenShift AI 3.0** - ML platform with LlamaStack operator
- **LlamaStack** - AI agent orchestration framework
- **vLLM / Azure OpenAI / OpenAI** - LLM inference (multiple providers supported)
- **FastMCP** - Python SDK for building MCP servers
- **MongoDB** - Data storage
- **Streamlit** - Demo UI

---

## Architecture

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

**Supported LLM Providers**:
| Provider | Use Case |
|----------|----------|
| vLLM (RHOAI) | Models deployed on OpenShift AI |
| Azure OpenAI | GPT-4, GPT-4o |
| OpenAI | GPT-4, GPT-4o |
| Ollama | Local development |
| AWS Bedrock | Claude, Llama, Titan |

**Data Flow**:
1. User asks: "What's the weather in Delhi?"
2. LlamaStack sends query + available tools to LLM
3. LLM decides to call `search_weather` tool with `station: "VIDP"`
4. LlamaStack invokes MCP server with tool call
5. MCP server queries MongoDB, returns weather data
6. LlamaStack sends tool result back to LLM
7. LLM generates human-readable response
8. UI displays response to user

---

## Prerequisites

- OpenShift cluster with OpenShift AI 3.0+ installed
- LlamaStack operator enabled (see [Enabling LlamaStack](#enabling-llamastack))
- `oc` CLI configured and logged in
- Access to an LLM (vLLM deployment, Azure OpenAI, OpenAI, etc.)

### Enabling LlamaStack

If LlamaStack is not enabled in your RHOAI installation:

```bash
# Check if LlamaStack CRD exists
oc get crd llamastackdistributions.llamastack.io

# If not found, enable it:
oc patch datasciencecluster default-dsc --type merge \
  -p '{"spec":{"components":{"llamastackoperator":{"managementState":"Managed"}}}}'

# Wait for CRD to be available (~2-3 minutes)
```

---

## Quick Start

### Option 1: Use the Deployment Script

```bash
git clone https://github.com/gymnatics/llamastack-demo.git
cd llamastack-demo
./deploy.sh
```

The script will guide you through deploying:
1. MongoDB with sample weather data
2. Weather MCP Server
3. Demo UI

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

## Component 1: MCP Server

The MCP (Model Context Protocol) server exposes your data/APIs as tools that LLMs can use.

### Key Implementation

**`mcp/http_app.py`** - Main MCP server application:

```python
from mcp.server.fastmcp import FastMCP
from mcp.server.transport_security import TransportSecuritySettings
from motor.motor_asyncio import AsyncIOMotorClient
import os

# Server configuration from environment
SERVER_NAME = os.getenv("MCP_SERVER_NAME", "weather-data")
MONGODB_URL = os.getenv("MONGODB_URL", "mongodb://mongodb:27017")
DATABASE_NAME = os.getenv("DATABASE_NAME", "weather")
COLLECTION_NAME = os.getenv("COLLECTION_NAME", "observations")

# IMPORTANT: Disable DNS rebinding protection for Kubernetes
# The MCP SDK validates Host headers, but K8s service names fail this check
transport_security = TransportSecuritySettings(
    enable_dns_rebinding_protection=False
)

# Initialize FastMCP server
mcp = FastMCP(SERVER_NAME, transport_security=transport_security)

# Global MongoDB client (async)
client = None
db = None

async def get_mongodb_client():
    """Get MongoDB client connection."""
    global client, db
    if client is None:
        client = AsyncIOMotorClient(MONGODB_URL)
        db = client[DATABASE_NAME]
    return client, db


@mcp.tool()
async def search_weather(
    station: str = None,
    location: str = None,
    min_temperature: float = None,
    max_temperature: float = None,
    min_visibility: int = None,
    max_visibility: int = None,
    conditions: str = None,
    hours_back: int = None,
    limit: int = 10
) -> str:
    """Search for weather observations with optional filters.

    Args:
        station: Station code (ICAO or local identifier)
        location: Location name or region to search
        min_temperature: Minimum temperature in Celsius
        max_temperature: Maximum temperature in Celsius
        min_visibility: Minimum visibility in meters
        max_visibility: Maximum visibility in meters
        conditions: Weather conditions to search for (e.g., 'rain', 'fog', 'clear')
        hours_back: Only include observations from the last N hours
        limit: Maximum results to return (default: 10, max: 50)
    
    Returns:
        Formatted weather observations matching the search criteria
    """
    _, db = await get_mongodb_client()
    
    # Build the query
    query = {}
    
    # Station filter - check multiple possible field names
    if station:
        station_upper = station.upper()
        query["$or"] = [
            {"station": station_upper},
            {"stationICAO": station_upper},
            {"station_id": station_upper}
        ]
    
    # Location filter - search in location-related fields
    if location:
        query["$or"] = query.get("$or", []) + [
            {"location": {"$regex": location, "$options": "i"}},
            {"station_name": {"$regex": location, "$options": "i"}},
            {"city": {"$regex": location, "$options": "i"}},
            {"region": {"$regex": location, "$options": "i"}}
        ]
    
    # Execute the query
    limit = min(limit, 50)
    cursor = db[COLLECTION_NAME].find(query).sort([("timestamp", -1)]).limit(limit)
    results = await cursor.to_list(length=limit)
    
    if not results:
        return "❌ No weather data found with the specified filters"
    
    return format_results(results)


@mcp.tool()
async def get_current_weather(station: str) -> str:
    """Get the most recent weather observation for a specific station.

    Args:
        station: Station code (ICAO code like 'VIDP' or local identifier)
    
    Returns:
        Current weather conditions at the station
    """
    _, db = await get_mongodb_client()
    
    station_upper = station.upper()
    query = {"$or": [
        {"station": station_upper},
        {"stationICAO": station_upper},
        {"station_id": station_upper}
    ]}
    
    doc = await db[COLLECTION_NAME].find_one(query, sort=[("timestamp", -1)])
    
    if not doc:
        return f"❌ No weather data found for station: {station}"
    
    return format_weather_observation(doc)


@mcp.tool()
async def list_stations() -> str:
    """List all available weather stations.

    Returns:
        List of all station codes available in the database
    """
    _, db = await get_mongodb_client()
    
    stations = set()
    for field in ["station", "stationICAO", "station_id"]:
        codes = await db[COLLECTION_NAME].distinct(field)
        stations.update(code for code in codes if code)
    
    return f"📡 Available Stations: {', '.join(sorted(stations))}"


@mcp.tool()
async def get_statistics() -> str:
    """Get statistics about the weather database."""
    _, db = await get_mongodb_client()
    
    total_docs = await db[COLLECTION_NAME].count_documents({})
    stations = set()
    for field in ["station", "stationICAO", "station_id"]:
        codes = await db[COLLECTION_NAME].distinct(field)
        stations.update(code for code in codes if code)
    
    return f"📊 Database: {total_docs:,} observations, {len(stations)} stations"


@mcp.tool()
async def health_check() -> str:
    """Check if the MCP server and database connection are healthy."""
    _, db = await get_mongodb_client()
    await db.command('ping')
    count = await db[COLLECTION_NAME].count_documents({})
    return f"✅ Healthy - Database connected, {count:,} documents available"


if __name__ == "__main__":
    import uvicorn
    app = mcp.streamable_http_app()
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

### Critical Configuration: DNS Rebinding Protection

**Problem**: When deployed in Kubernetes, the MCP server receives requests with `Host: weather-mcp-server.demo-test.svc.cluster.local`. The MCP SDK's default security settings reject this as a potential DNS rebinding attack.

**Error you'll see**:
```
HTTP 421: Invalid Host header
```

**Solution**: Disable DNS rebinding protection when running in Kubernetes:

```python
from mcp.server.transport_security import TransportSecuritySettings

transport_security = TransportSecuritySettings(
    enable_dns_rebinding_protection=False
)
mcp = FastMCP("weather-data", transport_security=transport_security)
```

### Available Tools

| Tool | Description |
|------|-------------|
| `search_weather` | Search observations with filters (station, location, temperature, conditions) |
| `get_current_weather` | Get latest observation for a specific station |
| `list_stations` | List all available weather stations |
| `get_statistics` | Get database statistics and coverage |
| `health_check` | Check server and database health |

### Sample Data Schema

```json
{
  "station": "VIDP",
  "station_name": "Delhi - Indira Gandhi International",
  "city": "New Delhi",
  "country": "India",
  "location": {"lat": 28.5665, "lon": 77.1031},
  "timestamp": "2024-01-01T12:00:00Z",
  "temperature": 32.5,
  "dewpoint": 18.2,
  "humidity": 45,
  "wind_speed": 8,
  "wind_direction": 270,
  "visibility": 10000,
  "pressure": 1013.2,
  "conditions": "Partly Cloudy",
  "source": "demo-data"
}
```

### Deployment Configuration

```yaml
# mcp/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: weather-mcp-server
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: mcp-server
        image: image-registry.openshift-image-registry.svc:5000/demo-test/weather-mcp-server:latest
        ports:
        - containerPort: 8000
        env:
        - name: MCP_SERVER_NAME
          value: "weather-data"
        - name: MONGODB_URL
          value: "mongodb://mongodb:27017"
        - name: DATABASE_NAME
          value: "weather"
        - name: COLLECTION_NAME
          value: "observations"
        # Use TCP probe - MCP servers don't have HTTP health endpoints
        readinessProbe:
          tcpSocket:
            port: 8000
        livenessProbe:
          tcpSocket:
            port: 8000
```

---

## Component 2: LLM with Tool Calling

Not all LLMs support tool calling. Here's what works:

### Supported Models

| Model | Provider | Tool Parser |
|-------|----------|-------------|
| Qwen3-8B | vLLM | `hermes` |
| Llama 3.1+ | vLLM | `llama3_json` |
| Mistral | vLLM | `mistral` |
| GPT-4o | Azure/OpenAI | Native |
| Claude 3 | Bedrock | Native |

### vLLM Configuration for Tool Calling

If using vLLM, you **must** add these arguments to the ServingRuntime:

```yaml
apiVersion: serving.kserve.io/v1alpha1
kind: ServingRuntime
metadata:
  name: vllm-runtime
spec:
  containers:
  - name: kserve-container
    image: quay.io/modh/vllm:latest
    args:
    - --port=8080
    - --model=/mnt/models
    - --served-model-name={{.Name}}
    - --enable-auto-tool-choice        # REQUIRED for tool calling
    - --tool-call-parser=hermes        # REQUIRED: parser format
    - --dtype=half
    - --max-model-len=20000
```

### Tool Call Parser Options

| Model | Parser |
|-------|--------|
| Qwen3 | `hermes` |
| Llama 3.1+ | `llama3_json` |
| Mistral | `mistral` |

### Symptom of Missing Tool Parser

If the model doesn't respond when you ask a question that should trigger tool use:
1. Check vLLM logs - you won't see any tool call output
2. The model may return empty or incomplete responses
3. LlamaStack logs show no tool invocations

---

## Component 3: LlamaStack Orchestration

LlamaStack sits between the UI and the LLM, managing tool registration and execution.

### LlamaStack ConfigMap Structure

```yaml
# llamastack/llamastack-config-vllm.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: llamastack-demo-llm-config
data:
  run.yaml: |
    version: "2"
    image_name: rh
    apis:
    - agents
    - inference
    - tool_runtime
    - vector_io
    providers:
      inference:
      - provider_id: vllm-inference
        provider_type: remote::vllm
        config:
          url: ${env.VLLM_URL}/v1
          api_token: ${env.VLLM_API_TOKEN:}
      tool_runtime:
      - provider_id: model-context-protocol
        provider_type: remote::model-context-protocol
        config: {}
    models:
    - provider_id: vllm-inference
      model_id: qwen3-8b
      model_type: llm
    tool_groups:
    - toolgroup_id: builtin::rag
      provider_id: rag-runtime
    - toolgroup_id: mcp::weather-data
      provider_id: model-context-protocol
      mcp_endpoint:
        uri: http://weather-mcp-server.demo-test.svc.cluster.local:8000/mcp
```

### Registering MCP with LlamaStack

The key configuration is in `tool_groups`:

```yaml
tool_groups:
- toolgroup_id: mcp::weather-data          # Format: mcp::<server-name>
  provider_id: model-context-protocol
  mcp_endpoint:
    uri: http://weather-mcp-server.NAMESPACE.svc.cluster.local:8000/mcp
```

### Finding and Editing the LlamaStack ConfigMap

```bash
# Step 1: Find which ConfigMap your LlamaStack uses
oc get deployment lsd-genai-playground -o yaml | grep -A10 "volumes:"
# Look for the "user-config" volume - note the ConfigMap name

# Step 2: Get the current config
oc get configmap llama-stack-config -n demo-test \
  -o jsonpath='{.data.run\.yaml}' > /tmp/llama-config.yaml

# Step 3: Edit and add the MCP toolgroup (see above)

# Step 4: Apply and restart
oc create configmap llama-stack-config \
  --from-file=run.yaml=/tmp/llama-config.yaml \
  -n demo-test --dry-run=client -o yaml | oc apply -f -

oc delete pod -l app=llama-stack -n demo-test
```

### Verify Tools are Registered

```bash
# From inside the cluster
curl -s http://llamastack-demo-service:8321/v1/tools | jq '.data[].name'

# Expected output:
"search_weather"
"get_current_weather"
"list_stations"
"get_statistics"
"health_check"
```

### Common Mistake: Wrong ConfigMap

OpenShift AI may create multiple ConfigMaps with similar names:
- `llama-stack-config` (actual mounted config)
- `lsd-genai-playground-config` (may exist but not used)

Always check which one is actually mounted in the deployment!

---

## Component 4: Demo UI

A reusable Streamlit app for demonstrating the system. Fully configurable via environment variables.

### Configuration Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `LLAMASTACK_URL` | ✅ | LlamaStack service endpoint |
| `MODEL_ID` | ✅ | Model ID registered in LlamaStack |
| `MCP_SERVER_URL` | ✅ | MCP server URL (for health checks) |
| `APP_TITLE` | ❌ | Page title |
| `MCP_SERVER_NAME` | ❌ | Name shown in architecture diagram |
| `DATA_SOURCE_NAME` | ❌ | Data source name in diagram |
| `CHAT_PLACEHOLDER` | ❌ | Placeholder text in chat input |

### Deployment ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: llamastack-demo-config
data:
  LLAMASTACK_URL: "http://llamastack-demo-service.demo-test.svc.cluster.local:8321"
  MODEL_ID: "qwen3-8b"
  MCP_SERVER_URL: "http://weather-mcp-server.demo-test.svc.cluster.local:8000"
  APP_TITLE: "Weather AI Assistant"
  MCP_SERVER_NAME: "Weather MCP"
  DATA_SOURCE_NAME: "MongoDB"
```

### Handling MCP Tool Responses

MCP tools return responses in this format:
```json
{
  "content": [
    {"type": "text", "text": "... actual data ..."}
  ]
}
```

The UI handles this structure:

```python
def execute_tool_call(tool_name: str, tool_args: Dict) -> str:
    response = requests.post(
        f"{LLAMASTACK_URL}/v1/tool-runtime/invoke",
        json={"tool_name": tool_name, "kwargs": tool_args}
    )
    result = response.json()
    
    # Handle nested response structure
    if isinstance(result, dict):
        content = result.get("content", result)
        if isinstance(content, list):
            return "\n".join(
                item.get("text", json.dumps(item)) 
                if isinstance(item, dict) else str(item)
                for item in content
            )
    return str(result)
```

---

## Connecting the Components

### Service Discovery

| Component | Service Name | Port | Endpoint |
|-----------|-------------|------|----------|
| MCP Server | `weather-mcp-server` | 8000 | `/mcp` |
| LlamaStack | `llamastack-demo-service` | 8321 | `/v1/tools`, `/v1/inference/chat-completion` |
| MongoDB | `mongodb` | 27017 | - |
| Demo UI | `llamastack-mcp-demo` | 8501 | `/` |

### Testing Connectivity

```bash
# Test MCP Server - List available tools
oc exec deployment/llamastack-mcp-demo -- \
  curl -s http://weather-mcp-server:8000/mcp \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","method":"tools/list","id":1}'

# Test LlamaStack tools endpoint
oc exec deployment/llamastack-mcp-demo -- \
  curl -s http://llamastack-demo-service:8321/v1/tools

# Test MCP tool invocation directly
oc exec deployment/weather-mcp-server -- \
  curl -s http://localhost:8000/mcp \
  -X POST \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"list_stations","arguments":{}},"id":2}'
```

---

## Troubleshooting

### Problem: "HTTP 421: Invalid Host header"

**Cause**: MCP SDK's DNS rebinding protection rejects Kubernetes service hostnames.

**Solution**: Disable protection in MCP server:
```python
from mcp.server.transport_security import TransportSecuritySettings

transport_security = TransportSecuritySettings(enable_dns_rebinding_protection=False)
mcp = FastMCP("weather-data", transport_security=transport_security)
```

### Problem: Model doesn't call tools (no response or incomplete)

**Cause**: vLLM not configured for tool calling.

**Solution**: Add to ServingRuntime args:
```yaml
- --enable-auto-tool-choice
- --tool-call-parser=hermes  # or appropriate parser for your model
```

### Problem: "No tools found" or only RAG tools showing

**Cause**: MCP server not registered in LlamaStack config.

**Solution**: Add toolgroup to LlamaStack ConfigMap:
```yaml
tool_groups:
- toolgroup_id: mcp::weather-data
  provider_id: model-context-protocol
  mcp_endpoint:
    uri: http://weather-mcp-server:8000/mcp
```

### Problem: "Failed to resolve 'service-name.namespace.svc.cluster.local'"

**Cause**: Wrong service name in configuration.

**Solution**: 
1. Check actual service name: `oc get svc -n your-namespace`
2. OpenShift AI often adds `-service` suffix to service names
3. Update ConfigMaps with correct service name

### Problem: MCP Server pod not ready (health probe failing)

**Cause**: HTTP health probes fail because MCP servers don't expose a `/health` endpoint by default.

**Solution**: Use TCP socket probes instead:
```yaml
readinessProbe:
  tcpSocket:
    port: 8000
  initialDelaySeconds: 5
  periodSeconds: 10
livenessProbe:
  tcpSocket:
    port: 8000
  initialDelaySeconds: 10
  periodSeconds: 20
```

### Problem: MongoDB image pull error

**Cause**: Cluster image registry mirrors blocking Docker Hub.

**Solution**: Use full image path:
```yaml
image: docker.io/library/mongo:6.0
```

### Problem: "TypeError: sequence item 0: expected str instance, list found"

**Cause**: MCP tool response contains nested list structure not being handled.

**Solution**: Parse the response structure properly:
```python
if isinstance(content, list):
    return "\n".join(
        item.get("text", json.dumps(item)) if isinstance(item, dict) else str(item)
        for item in content
    )
```

---

## Lessons Learned

### 1. Security Settings Need Kubernetes Awareness

The MCP SDK's default security settings are designed for localhost development. In Kubernetes, you must explicitly disable DNS rebinding protection or the server will reject all requests.

### 2. Tool Calling Requires Explicit LLM Configuration

Just because a model supports tool calling doesn't mean vLLM will enable it. You must explicitly add `--enable-auto-tool-choice` and the correct `--tool-call-parser` argument.

### 3. Multiple ConfigMaps Can Cause Confusion

OpenShift AI creates multiple ConfigMaps. Always verify which one is actually mounted in the deployment before making changes.

### 4. Service Names May Not Match Deployment Names

OpenShift AI often appends `-service` to service names. Always check `oc get svc` to find the actual service name.

### 5. MCP Response Format Requires Careful Parsing

MCP tools return structured responses with nested content arrays. Your application must handle this format, not assume plain strings.

### 6. Use TCP Probes for MCP Servers

MCP servers using FastMCP don't expose HTTP health endpoints by default. Use TCP socket probes instead of HTTP GET probes.

### 7. End-to-End Testing is Essential

Each component may work in isolation but fail when connected. Test the full chain: UI → LlamaStack → LLM → MCP → Database.

---

## Sample Weather Stations

The demo includes 14 global weather stations with 48 hours of sample data:

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

## Example Queries

Once the system is deployed, try asking:

- "What's the current weather in Delhi?"
- "Find all stations with temperature above 30°C"
- "Which airports have fog right now?"
- "List all available weather stations"
- "Compare the weather in London and New York"
- "Show me the weather statistics"

---

## References

- [Model Context Protocol (MCP) Specification](https://modelcontextprotocol.io/)
- [LlamaStack Documentation](https://github.com/meta-llama/llama-stack)
- [vLLM Tool Calling](https://docs.vllm.ai/en/latest/features/tool_calling.html)
- [FastMCP Python SDK](https://github.com/jlowin/fastmcp)
- [OpenShift AI Documentation](https://docs.redhat.com/en/documentation/red_hat_openshift_ai_self-managed/)

---

**Repository**: https://github.com/gymnatics/llamastack-demo

*Author: Danny Yeo*

*Last updated: January 2026*
