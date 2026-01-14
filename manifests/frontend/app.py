"""
LlamaStack Multi-MCP Demo UI
Enhanced interface supporting multiple MCP servers with dynamic management
MCP servers are auto-detected from LlamaStack's configured toolgroups
"""
import streamlit as st
import requests
import json
import os
from datetime import datetime
from typing import List, Dict, Any, Optional

# Configuration from environment or defaults
DEFAULT_LLAMASTACK_URL = os.getenv("LLAMASTACK_URL", "http://localhost:8321")
DEFAULT_MODEL_ID = os.getenv("MODEL_ID", "")  # Will be auto-detected if empty

def get_llamastack_url() -> str:
    """Get the current LlamaStack URL from session state or default."""
    if "llamastack_url" in st.session_state:
        return st.session_state.llamastack_url
    return DEFAULT_LLAMASTACK_URL

def get_model_id() -> str:
    """Get the current model ID from session state or default."""
    if "selected_model_id" in st.session_state and st.session_state.selected_model_id:
        return st.session_state.selected_model_id
    return DEFAULT_MODEL_ID

# MCP Server metadata for display (icon, description)
MCP_SERVER_METADATA = {
    "mcp::weather-data": {
        "name": "Weather",
        "icon": "🌤️",
        "description": "Weather data via OpenWeatherMap API"
    },
    "mcp::hr-tools": {
        "name": "HR Tools",
        "icon": "👥",
        "description": "Employee info, vacation, job openings"
    },
    "mcp::jira-confluence": {
        "name": "Jira/Confluence",
        "icon": "📋",
        "description": "Issue tracking and documentation"
    },
    "mcp::github-tools": {
        "name": "GitHub",
        "icon": "🐙",
        "description": "Repository search, issues, code search"
    },
    "builtin::rag": {
        "name": "RAG",
        "icon": "🔍",
        "description": "Built-in retrieval augmented generation"
    }
}

def get_available_models() -> List[Dict]:
    """Fetch available models from LlamaStack."""
    try:
        url = get_llamastack_url()
        response = requests.get(f"{url}/v1/models", timeout=5)
        if response.status_code == 200:
            data = response.json()
            # Filter to only LLM models (not embeddings)
            return [m for m in data.get("data", []) if m.get("model_type") == "llm"]
    except:
        pass
    return []

def get_default_model_id() -> str:
    """Get the default model ID - either from session state, env, or auto-detect."""
    # Check session state first
    if "selected_model_id" in st.session_state and st.session_state.selected_model_id:
        return st.session_state.selected_model_id
    
    # Check env var
    if DEFAULT_MODEL_ID:
        return DEFAULT_MODEL_ID
    
    # Auto-detect from LlamaStack
    models = get_available_models()
    if models:
        # Prefer the first LLM model
        model_id = models[0].get("identifier", "")
        st.session_state.selected_model_id = model_id
        return model_id
    
    # Fallback
    return "llama-32-3b-instruct"

def get_available_tools() -> List[Dict]:
    """Fetch available MCP tools from LlamaStack."""
    try:
        url = get_llamastack_url()
        response = requests.get(f"{url}/v1/tools", timeout=10)
        if response.status_code == 200:
            data = response.json()
            if isinstance(data, list):
                return data
            return data.get("data", [])
    except Exception as e:
        pass
    return []

def extract_mcp_servers_from_tools(tools: List[Dict]) -> List[Dict]:
    """Extract unique MCP servers from the tools list."""
    toolgroups = set()
    for tool in tools:
        toolgroup_id = tool.get("toolgroup_id", "")
        if toolgroup_id:
            toolgroups.add(toolgroup_id)
    
    servers = []
    for tg in sorted(toolgroups):
        metadata = MCP_SERVER_METADATA.get(tg, {
            "name": tg.replace("mcp::", "").replace("::", " ").title(),
            "icon": "🔧",
            "description": f"Tools from {tg}"
        })
        
        # Count tools in this group
        tool_count = len([t for t in tools if t.get("toolgroup_id") == tg])
        
        servers.append({
            "toolgroup_id": tg,
            "name": metadata["name"],
            "icon": metadata["icon"],
            "description": f"{metadata['description']} ({tool_count} tools)",
            "tool_count": tool_count,
            "enabled": True
        })
    
    return servers

# UI Customization
APP_TITLE = os.getenv("APP_TITLE", "LlamaStack Multi-MCP Demo")
APP_SUBTITLE = os.getenv("APP_SUBTITLE", "AI Agent with Multiple Tool Integrations")
SYSTEM_PROMPT = os.getenv("SYSTEM_PROMPT", """You are an intelligent AI assistant with access to multiple external tools through MCP servers.

Use the appropriate tools to answer user questions accurately. Always explain what tools you're using and why.""")

# Page config
st.set_page_config(
    page_title=APP_TITLE,
    page_icon="🦙",
    layout="wide",
    initial_sidebar_state="expanded"
)

# Custom CSS for modern dark theme
st.markdown("""
<style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap');
    
    :root {
        --primary: #8b5cf6;
        --primary-light: #a78bfa;
        --secondary: #10b981;
        --accent: #f59e0b;
        --danger: #ef4444;
        --background: #0f172a;
        --surface: #1e293b;
        --surface-light: #334155;
        --text: #f1f5f9;
        --text-muted: #94a3b8;
        --border: #475569;
    }
    
    .stApp {
        font-family: 'Inter', sans-serif;
    }
    
    /* Header */
    .main-header {
        background: linear-gradient(135deg, #6366f1 0%, #8b5cf6 50%, #a855f7 100%);
        padding: 1.5rem 2rem;
        border-radius: 16px;
        margin-bottom: 1.5rem;
        box-shadow: 0 4px 20px rgba(99, 102, 241, 0.3);
    }
    
    .main-header h1 {
        color: white;
        font-weight: 700;
        margin: 0;
        font-size: 1.8rem;
    }
    
    .main-header p {
        color: rgba(255,255,255,0.85);
        margin: 0.5rem 0 0 0;
    }
    
    /* MCP Server Cards */
    .mcp-server-card {
        background: linear-gradient(145deg, #1e293b 0%, #0f172a 100%);
        border: 1px solid #334155;
        border-radius: 12px;
        padding: 1rem;
        margin: 0.5rem 0;
        transition: all 0.2s ease;
    }
    
    .mcp-server-card:hover {
        border-color: #8b5cf6;
        box-shadow: 0 0 15px rgba(139, 92, 246, 0.2);
    }
    
    .mcp-server-card.enabled {
        border-left: 3px solid #10b981;
    }
    
    .mcp-server-card.disabled {
        border-left: 3px solid #475569;
        opacity: 0.7;
    }
    
    .mcp-server-header {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        margin-bottom: 0.5rem;
    }
    
    .mcp-server-icon {
        font-size: 1.5rem;
    }
    
    .mcp-server-name {
        font-weight: 600;
        color: #f1f5f9;
    }
    
    .mcp-server-desc {
        font-size: 0.8rem;
        color: #94a3b8;
    }
    
    /* Status badges */
    .status-badge {
        display: inline-flex;
        align-items: center;
        gap: 0.3rem;
        padding: 0.2rem 0.6rem;
        border-radius: 12px;
        font-size: 0.7rem;
        font-weight: 600;
    }
    
    .status-badge.online {
        background: rgba(16, 185, 129, 0.2);
        color: #10b981;
        border: 1px solid #10b981;
    }
    
    .status-badge.offline {
        background: rgba(239, 68, 68, 0.2);
        color: #ef4444;
        border: 1px solid #ef4444;
    }
    
    .status-badge.checking {
        background: rgba(245, 158, 11, 0.2);
        color: #f59e0b;
        border: 1px solid #f59e0b;
    }
    
    /* Tool call styling */
    .tool-call-box {
        background: linear-gradient(135deg, #064e3b 0%, #022c22 100%);
        border: 1px solid #10b981;
        border-radius: 10px;
        padding: 1rem;
        margin: 0.75rem 0;
        font-family: 'JetBrains Mono', monospace;
        font-size: 0.8rem;
    }
    
    .tool-call-header {
        color: #10b981;
        font-weight: 600;
        margin-bottom: 0.5rem;
        display: flex;
        align-items: center;
        gap: 0.5rem;
    }
    
    .tool-call-content {
        color: #a7f3d0;
        white-space: pre-wrap;
        overflow-x: auto;
    }
    
    /* Tool result styling */
    .tool-result-box {
        background: linear-gradient(135deg, #1e3a5f 0%, #0f172a 100%);
        border: 1px solid #3b82f6;
        border-radius: 10px;
        padding: 1rem;
        margin: 0.75rem 0;
        font-family: 'JetBrains Mono', monospace;
        font-size: 0.8rem;
    }
    
    .tool-result-header {
        color: #60a5fa;
        font-weight: 600;
        margin-bottom: 0.5rem;
    }
    
    .tool-result-content {
        color: #bfdbfe;
        white-space: pre-wrap;
        overflow-x: auto;
        max-height: 300px;
        overflow-y: auto;
    }
    
    /* Architecture diagram */
    .architecture-container {
        background: linear-gradient(145deg, #1e293b 0%, #0f172a 100%);
        border: 1px solid #334155;
        border-radius: 12px;
        padding: 1.5rem;
        margin: 1rem 0;
    }
    
    .flow-diagram {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 0.5rem;
        flex-wrap: wrap;
        padding: 1rem;
    }
    
    .flow-box {
        background: linear-gradient(135deg, #334155, #1e293b);
        border: 2px solid #6366f1;
        border-radius: 10px;
        padding: 0.75rem 1rem;
        color: #f1f5f9;
        font-weight: 600;
        font-size: 0.85rem;
        text-align: center;
        min-width: 100px;
    }
    
    .flow-box.mcp {
        border-color: #10b981;
        background: linear-gradient(135deg, #064e3b, #0f172a);
    }
    
    .flow-box.llm {
        border-color: #f59e0b;
        background: linear-gradient(135deg, #451a03, #0f172a);
    }
    
    .flow-arrow {
        color: #6366f1;
        font-size: 1.2rem;
        font-weight: bold;
    }
    
    /* Metrics */
    .metrics-container {
        display: flex;
        gap: 1rem;
        margin: 1rem 0;
    }
    
    .metric-card {
        flex: 1;
        background: #1e293b;
        border-radius: 10px;
        padding: 1rem;
        text-align: center;
        border: 1px solid #334155;
    }
    
    .metric-value {
        font-size: 1.5rem;
        font-weight: 700;
        color: #8b5cf6;
    }
    
    .metric-label {
        font-size: 0.75rem;
        color: #94a3b8;
        text-transform: uppercase;
    }
</style>
""", unsafe_allow_html=True)

# Initialize session state
if "messages" not in st.session_state:
    st.session_state.messages = []
if "mcp_servers" not in st.session_state:
    st.session_state.mcp_servers = []  # Will be populated from LlamaStack
if "mcp_tools" not in st.session_state:
    st.session_state.mcp_tools = []
if "llamastack_status" not in st.session_state:
    st.session_state.llamastack_status = "unknown"
if "tool_calls_count" not in st.session_state:
    st.session_state.tool_calls_count = 0


def check_llamastack_health() -> bool:
    """Check if LlamaStack is healthy."""
    try:
        url = get_llamastack_url()
        response = requests.get(f"{url}/v1/health", timeout=5)
        return response.status_code == 200
    except:
        return False


def refresh_tools_and_servers():
    """Refresh tools and extract MCP servers from them."""
    tools = get_available_tools()
    st.session_state.mcp_tools = tools
    st.session_state.mcp_servers = extract_mcp_servers_from_tools(tools)
    return tools


def chat_completion_openai(messages: List[Dict], tools: List[Dict] = None) -> Dict:
    """Send chat completion request using OpenAI-compatible endpoint."""
    payload = {
        "model": get_default_model_id(),
        "messages": messages,
        "temperature": 0.7,
        "max_tokens": 4096,
    }
    
    if tools:
        payload["tools"] = tools
        payload["tool_choice"] = "auto"
    
    try:
        url = get_llamastack_url()
        response = requests.post(
            f"{url}/v1/openai/v1/chat/completions",
            json=payload,
            timeout=120
        )
        response.raise_for_status()
        return response.json()
    except requests.exceptions.RequestException as e:
        return {"error": str(e)}


def format_tools_for_openai(mcp_tools: List[Dict]) -> List[Dict]:
    """Convert MCP tools to OpenAI function calling format."""
    openai_tools = []
    for tool in mcp_tools:
        openai_tool = {
            "type": "function",
            "function": {
                "name": tool.get("name", tool.get("identifier", "")),
                "description": tool.get("description", ""),
                "parameters": tool.get("parameters", tool.get("parameter_definitions", {
                    "type": "object",
                    "properties": {},
                    "required": []
                }))
            }
        }
        openai_tools.append(openai_tool)
    return openai_tools


def execute_tool_call(tool_name: str, tool_args: Dict) -> str:
    """Execute a tool call via LlamaStack."""
    try:
        url = get_llamastack_url()
        response = requests.post(
            f"{url}/v1/tool-runtime/invoke",
            json={
                "tool_name": tool_name,
                "kwargs": tool_args
            },
            timeout=60
        )
        response.raise_for_status()
        result = response.json()
        
        if isinstance(result, dict):
            content = result.get("content", result)
            if isinstance(content, list):
                return "\n".join(
                    item.get("text", json.dumps(item)) if isinstance(item, dict) else str(item)
                    for item in content
                )
            elif isinstance(content, dict):
                return json.dumps(content, indent=2)
            return str(content)
        elif isinstance(result, list):
            return "\n".join(
                item.get("text", json.dumps(item)) if isinstance(item, dict) else str(item)
                for item in result
            )
        return str(result)
    except Exception as e:
        return f"Tool execution error: {str(e)}"


def toggle_mcp_server(index: int):
    """Toggle an MCP server on/off."""
    if 0 <= index < len(st.session_state.mcp_servers):
        st.session_state.mcp_servers[index]["enabled"] = not st.session_state.mcp_servers[index]["enabled"]


# ============== HEADER ==============
st.markdown(f"""
<div class="main-header">
    <h1>🦙 {APP_TITLE}</h1>
    <p>{APP_SUBTITLE}</p>
</div>
""", unsafe_allow_html=True)

# ============== SIDEBAR ==============
with st.sidebar:
    st.markdown("### 🔧 Configuration")
    
    # Connection settings
    with st.expander("🌐 LlamaStack Endpoint", expanded=False):
        # Use session state for URL and model to avoid global issues
        if "llamastack_url" not in st.session_state:
            st.session_state.llamastack_url = DEFAULT_LLAMASTACK_URL
        if "selected_model_id" not in st.session_state:
            st.session_state.selected_model_id = DEFAULT_MODEL_ID
        
        new_llamastack_url = st.text_input(
            "LlamaStack URL",
            value=st.session_state.llamastack_url,
            help="LlamaStack service endpoint"
        )
        
        # Auto-detect available models
        available_models = get_available_models()
        model_options = [m.get("identifier", "") for m in available_models] if available_models else []
        current_model = get_default_model_id()
        
        if model_options:
            # Show dropdown with available models
            default_idx = model_options.index(current_model) if current_model in model_options else 0
            new_model_id = st.selectbox(
                "Model",
                options=model_options,
                index=default_idx,
                help="Auto-detected from LlamaStack"
            )
        else:
            # Fallback to text input if can't fetch models
            new_model_id = st.text_input(
                "Model ID", 
                value=current_model,
                help="Model identifier in LlamaStack"
            )
        
        # Update session state
        st.session_state.llamastack_url = new_llamastack_url
        st.session_state.selected_model_id = new_model_id
    
    st.markdown("---")
    
    # LlamaStack Status
    st.markdown("### 📡 LlamaStack Status")
    col1, col2 = st.columns([2, 1])
    with col1:
        ls_status = st.session_state.llamastack_status
        ls_class = "online" if ls_status == "online" else "offline" if ls_status == "offline" else "checking"
        st.markdown(f"""
        <div class="status-badge {ls_class}">
            ● {ls_status.upper()}
        </div>
        """, unsafe_allow_html=True)
    with col2:
        if st.button("🔄", key="check_ls"):
            st.session_state.llamastack_status = "online" if check_llamastack_health() else "offline"
            st.rerun()
    
    st.markdown("---")
    
    # MCP Servers Section - Now dynamically loaded!
    st.markdown("### 🔌 MCP Servers")
    st.caption("💡 Auto-detected from LlamaStack")
    
    # Refresh button - this now updates both tools AND servers
    if st.button("🔄 Refresh", use_container_width=True, key="refresh_all"):
        with st.spinner("Fetching from LlamaStack..."):
            tools = refresh_tools_and_servers()
            st.session_state.llamastack_status = "online" if tools else "offline"
        if st.session_state.mcp_servers:
            st.success(f"Found {len(st.session_state.mcp_servers)} MCP servers!")
        else:
            st.warning("No MCP servers found. Is LlamaStack running?")
        st.rerun()
    
    # Display MCP servers (dynamically loaded)
    if st.session_state.mcp_servers:
        for i, server in enumerate(st.session_state.mcp_servers):
            enabled_class = "enabled" if server.get("enabled", True) else "disabled"
            
            with st.container():
                col1, col2 = st.columns([4, 1])
                
                with col1:
                    st.markdown(f"""
                    <div class="mcp-server-card {enabled_class}">
                        <div class="mcp-server-header">
                            <span class="mcp-server-icon">{server['icon']}</span>
                            <span class="mcp-server-name">{server['name']}</span>
                        </div>
                        <div class="mcp-server-desc">{server['description']}</div>
                    </div>
                    """, unsafe_allow_html=True)
                
                with col2:
                    # Toggle button
                    toggle_label = "✓" if server.get("enabled", True) else "○"
                    if st.button(toggle_label, key=f"toggle_{i}", help="Toggle server"):
                        toggle_mcp_server(i)
                        st.rerun()
    else:
        st.info("Click 'Refresh' to load MCP servers from LlamaStack")
    
    st.markdown("---")
    
    # Tools section
    st.markdown("### 🛠️ Available Tools")
    
    if st.session_state.mcp_tools:
        # Group tools by toolgroup
        tool_groups = {}
        for tool in st.session_state.mcp_tools:
            toolgroup = tool.get("toolgroup_id", "other")
            if toolgroup not in tool_groups:
                tool_groups[toolgroup] = []
            tool_groups[toolgroup].append(tool)
        
        for group, tools in sorted(tool_groups.items()):
            metadata = MCP_SERVER_METADATA.get(group, {"icon": "📦", "name": group})
            with st.expander(f"{metadata.get('icon', '📦')} {metadata.get('name', group)} ({len(tools)})"):
                for tool in tools:
                    tool_name = tool.get("name", tool.get("identifier", "Unknown"))
                    st.caption(f"• {tool_name}")
    else:
        st.info("Click 'Refresh' to load tools")
    
    st.markdown("---")
    
    # Actions
    st.markdown("### ⚡ Actions")
    
    if st.button("🗑️ Clear Chat", use_container_width=True):
        st.session_state.messages = []
        st.session_state.tool_calls_count = 0
        st.rerun()

# ============== MAIN CONTENT ==============

# Architecture diagram
with st.expander("🏗️ Architecture Overview", expanded=True):
    enabled_servers = [s for s in st.session_state.mcp_servers if s.get("enabled", True)]
    
    st.markdown("""
    <div class="architecture-container">
        <div class="flow-diagram">
            <div class="flow-box">👤 User</div>
            <span class="flow-arrow">→</span>
            <div class="flow-box">🦙 LlamaStack</div>
            <span class="flow-arrow">→</span>
            <div class="flow-box llm">🤖 LLM</div>
            <span class="flow-arrow">→</span>
    """, unsafe_allow_html=True)
    
    # Show enabled MCP servers
    if enabled_servers:
        mcp_html = ""
        for server in enabled_servers:
            mcp_html += f'<div class="flow-box mcp">{server["icon"]} {server["name"]}</div>'
        
        st.markdown(f"""
                <div style="display: flex; flex-direction: column; gap: 0.5rem;">
                    {mcp_html}
                </div>
            </div>
        </div>
        """, unsafe_allow_html=True)
    else:
        st.markdown("""
                <div class="flow-box mcp">🔧 No MCP Servers</div>
            </div>
        </div>
        """, unsafe_allow_html=True)
    
    # Server details
    if enabled_servers:
        cols = st.columns(len(enabled_servers))
        for i, server in enumerate(enabled_servers):
            with cols[i]:
                st.markdown(f"""
                <div style="background: #1e293b; border-radius: 8px; padding: 0.75rem; text-align: center;">
                    <div style="font-size: 1.5rem;">{server['icon']}</div>
                    <div style="font-weight: 600; color: #f1f5f9;">{server['name']}</div>
                    <div style="font-size: 0.7rem; color: #10b981;">● {server.get('tool_count', 0)} tools</div>
                </div>
                """, unsafe_allow_html=True)

# Metrics
col1, col2, col3, col4 = st.columns(4)
with col1:
    st.metric("💬 Messages", len(st.session_state.messages))
with col2:
    st.metric("🔧 Tool Calls", st.session_state.tool_calls_count)
with col3:
    enabled_count = len([s for s in st.session_state.mcp_servers if s.get("enabled", True)])
    st.metric("🔌 Active MCPs", enabled_count)
with col4:
    st.metric("🛠️ Tools", len(st.session_state.mcp_tools))

st.markdown("---")

# Display chat messages
for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"])
        
        if "tool_calls" in message and message["tool_calls"]:
            for tc in message["tool_calls"]:
                st.markdown(f"""
                <div class="tool-call-box">
                    <div class="tool-call-header">🔧 Tool Call: {tc.get('name', 'unknown')}</div>
                    <div class="tool-call-content">{json.dumps(tc.get('args', {}), indent=2)}</div>
                </div>
                """, unsafe_allow_html=True)
        
        if "tool_result" in message and message["tool_result"]:
            result_preview = message["tool_result"][:500] + "..." if len(message["tool_result"]) > 500 else message["tool_result"]
            st.markdown(f"""
            <div class="tool-result-box">
                <div class="tool-result-header">📊 Tool Result</div>
                <div class="tool-result-content">{result_preview}</div>
            </div>
            """, unsafe_allow_html=True)

# Chat input
if prompt := st.chat_input("Ask a question... (e.g., 'What's the weather forecast?' or 'Check vacation balance for EMP001')"):
    st.session_state.messages.append({"role": "user", "content": prompt})
    with st.chat_message("user"):
        st.markdown(prompt)
    
    # Build messages for API
    api_messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    for msg in st.session_state.messages:
        api_messages.append({"role": msg["role"], "content": msg["content"]})
    
    # Get tools in OpenAI format
    tools = format_tools_for_openai(st.session_state.mcp_tools) if st.session_state.mcp_tools else None
    
    # Call LlamaStack
    with st.chat_message("assistant"):
        with st.spinner("🤔 Thinking..."):
            response = chat_completion_openai(api_messages, tools)
        
        if "error" in response:
            st.error(f"Error: {response['error']}")
            st.session_state.messages.append({
                "role": "assistant",
                "content": f"Sorry, I encountered an error: {response['error']}"
            })
        else:
            choice = response.get("choices", [{}])[0]
            message = choice.get("message", {})
            
            if message.get("tool_calls"):
                tool_calls_info = []
                tool_results = []
                
                for tool_call in message["tool_calls"]:
                    func = tool_call.get("function", {})
                    tool_name = func.get("name", "")
                    try:
                        tool_args = json.loads(func.get("arguments", "{}"))
                    except:
                        tool_args = {}
                    
                    tool_calls_info.append({
                        "name": tool_name,
                        "args": tool_args
                    })
                    
                    st.session_state.tool_calls_count += 1
                    
                    st.markdown(f"""
                    <div class="tool-call-box">
                        <div class="tool-call-header">🔧 Calling: {tool_name}</div>
                        <div class="tool-call-content">{json.dumps(tool_args, indent=2)}</div>
                    </div>
                    """, unsafe_allow_html=True)
                    
                    with st.spinner(f"⚙️ Executing {tool_name}..."):
                        result = execute_tool_call(tool_name, tool_args)
                        tool_results.append(result)
                    
                    result_preview = result[:500] + "..." if len(result) > 500 else result
                    st.markdown(f"""
                    <div class="tool-result-box">
                        <div class="tool-result-header">📊 Result from {tool_name}</div>
                        <div class="tool-result-content">{result_preview}</div>
                    </div>
                    """, unsafe_allow_html=True)
                
                st.session_state.messages.append({
                    "role": "assistant",
                    "content": "Using tools to fetch data...",
                    "tool_calls": tool_calls_info,
                    "tool_result": "\n".join(tool_results)
                })
                
                api_messages.append({
                    "role": "assistant",
                    "content": None,
                    "tool_calls": message["tool_calls"]
                })
                
                for i, tool_call in enumerate(message["tool_calls"]):
                    api_messages.append({
                        "role": "tool",
                        "tool_call_id": tool_call["id"],
                        "content": tool_results[i]
                    })
                
                with st.spinner("✨ Generating response..."):
                    final_response = chat_completion_openai(api_messages, tools)
                
                if "error" not in final_response:
                    final_content = final_response.get("choices", [{}])[0].get("message", {}).get("content", "")
                    st.markdown(final_content)
                    st.session_state.messages.append({
                        "role": "assistant",
                        "content": final_content
                    })
                else:
                    st.error(f"Error generating final response: {final_response['error']}")
            else:
                content = message.get("content", "")
                st.markdown(content)
                st.session_state.messages.append({
                    "role": "assistant",
                    "content": content
                })

# Footer
st.markdown("---")
enabled_servers = [s["name"] for s in st.session_state.mcp_servers if s.get("enabled", True)]
current_model_display = get_default_model_id() or "Not detected"
st.markdown(f"""
<div style="text-align: center; color: #64748b; font-size: 0.8rem;">
    <p>🦙 LlamaStack Multi-MCP Demo | Model: {current_model_display}</p>
    <p>Active MCP Servers: {', '.join(enabled_servers) if enabled_servers else 'Click Refresh to load'}</p>
</div>
""", unsafe_allow_html=True)
