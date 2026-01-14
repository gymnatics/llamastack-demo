"""
LlamaStack Multi-MCP Demo UI
Enhanced interface supporting multiple MCP servers with dynamic management
"""
import streamlit as st
import requests
import json
import os
from datetime import datetime
from typing import List, Dict, Any, Optional

# Configuration from environment or defaults
LLAMASTACK_URL = os.getenv("LLAMASTACK_URL", "http://localhost:8321")
MODEL_ID = os.getenv("MODEL_ID", "llama-32-3b-instruct")

# Default MCP Servers (can be overridden via environment)
# NOTE: Weather MCP is colleague's OpenWeatherMap version on port 80 (service port)
DEFAULT_MCP_SERVERS = json.loads(os.getenv("MCP_SERVERS", json.dumps([
    {
        "name": "Weather",
        "url": "http://mcp-weather.my-first-model.svc.cluster.local:80",
        "description": "Weather data via OpenWeatherMap API",
        "icon": "🌤️",
        "enabled": True
    },
    {
        "name": "HR Tools",
        "url": "http://hr-mcp-server.my-first-model.svc.cluster.local:8000",
        "description": "Employee info, vacation, job openings, performance reviews",
        "icon": "👥",
        "enabled": True
    },
    {
        "name": "Jira/Confluence",
        "url": "http://jira-mcp-server.my-first-model.svc.cluster.local:8000",
        "description": "Issue tracking and documentation",
        "icon": "📋",
        "enabled": True
    },
    {
        "name": "GitHub",
        "url": "http://github-mcp-server.my-first-model.svc.cluster.local:8000",
        "description": "Repository search, issues, code search, user profiles",
        "icon": "🐙",
        "enabled": True
    }
])))

# UI Customization
APP_TITLE = os.getenv("APP_TITLE", "LlamaStack Multi-MCP Demo")
APP_SUBTITLE = os.getenv("APP_SUBTITLE", "AI Agent with Multiple Tool Integrations")
SYSTEM_PROMPT = os.getenv("SYSTEM_PROMPT", """You are an intelligent AI assistant with access to multiple external tools through MCP servers.

Available tool categories:
- Weather: Get real-time weather forecasts (getforecast)
- HR: Check vacation balances, employee info, job openings, performance reviews (get_vacation_balance, get_employee_info, list_employees, list_job_openings, get_performance_review, create_vacation_request)
- Jira/Confluence: Search issues, create tickets, find documentation (search_issues, get_issue_details, create_issue, search_confluence, get_page_content, list_projects, get_sprint_info)
- GitHub: Search repositories, get repo details, list issues, search code, get user profiles (search_repositories, get_repository, list_issues, create_issue, search_code, get_user)

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
    
    /* Add MCP form */
    .add-mcp-form {
        background: #1e293b;
        border: 1px dashed #475569;
        border-radius: 10px;
        padding: 1rem;
        margin-top: 1rem;
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
    st.session_state.mcp_servers = DEFAULT_MCP_SERVERS.copy()
if "mcp_tools" not in st.session_state:
    st.session_state.mcp_tools = []
if "llamastack_status" not in st.session_state:
    st.session_state.llamastack_status = "unknown"
if "mcp_statuses" not in st.session_state:
    st.session_state.mcp_statuses = {}
if "tool_calls_count" not in st.session_state:
    st.session_state.tool_calls_count = 0
if "show_add_mcp" not in st.session_state:
    st.session_state.show_add_mcp = False


def check_llamastack_health() -> bool:
    """Check if LlamaStack is healthy."""
    try:
        response = requests.get(f"{LLAMASTACK_URL}/v1/health", timeout=5)
        return response.status_code == 200
    except:
        return False


def check_mcp_health(url: str) -> bool:
    """Check if an MCP server is healthy."""
    try:
        # Try health endpoint first
        health_url = f"{url}/health"
        response = requests.get(health_url, timeout=5)
        if response.status_code == 200:
            return True
        
        # Try MCP initialize
        response = requests.post(
            f"{url}/mcp",
            json={
                "jsonrpc": "2.0",
                "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {},
                    "clientInfo": {"name": "healthcheck", "version": "1.0"}
                },
                "id": 1
            },
            headers={"Content-Type": "application/json"},
            timeout=5
        )
        return response.status_code == 200
    except:
        return False


def get_available_tools() -> List[Dict]:
    """Fetch available MCP tools from LlamaStack."""
    try:
        response = requests.get(f"{LLAMASTACK_URL}/v1/tools", timeout=10)
        if response.status_code == 200:
            data = response.json()
            if isinstance(data, list):
                return data
            return data.get("data", [])
    except Exception as e:
        st.error(f"Could not fetch tools: {e}")
    return []


def chat_completion_openai(messages: List[Dict], tools: List[Dict] = None) -> Dict:
    """Send chat completion request using OpenAI-compatible endpoint."""
    payload = {
        "model": MODEL_ID,
        "messages": messages,
        "temperature": 0.7,
        "max_tokens": 4096,
    }
    
    if tools:
        payload["tools"] = tools
        payload["tool_choice"] = "auto"
    
    try:
        response = requests.post(
            f"{LLAMASTACK_URL}/v1/openai/v1/chat/completions",
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
        response = requests.post(
            f"{LLAMASTACK_URL}/v1/tool-runtime/invoke",
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


def add_mcp_server(name: str, url: str, description: str, icon: str = "🔧"):
    """Add a new MCP server to the session."""
    new_server = {
        "name": name,
        "url": url,
        "description": description,
        "icon": icon,
        "enabled": True
    }
    st.session_state.mcp_servers.append(new_server)


def remove_mcp_server(index: int):
    """Remove an MCP server from the session."""
    if 0 <= index < len(st.session_state.mcp_servers):
        st.session_state.mcp_servers.pop(index)


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
        new_llamastack_url = st.text_input(
            "LlamaStack URL",
            value=LLAMASTACK_URL,
            help="LlamaStack service endpoint"
        )
        new_model_id = st.text_input(
            "Model ID", 
            value=MODEL_ID,
            help="Model identifier in LlamaStack"
        )
        
        if new_llamastack_url != LLAMASTACK_URL:
            LLAMASTACK_URL = new_llamastack_url
        if new_model_id != MODEL_ID:
            MODEL_ID = new_model_id
    
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
    
    # MCP Servers Section
    st.markdown("### 🔌 MCP Servers")
    
    # Check all servers button
    if st.button("🔄 Check All Servers", use_container_width=True):
        for i, server in enumerate(st.session_state.mcp_servers):
            status = "online" if check_mcp_health(server["url"]) else "offline"
            st.session_state.mcp_statuses[server["name"]] = status
        st.rerun()
    
    # Display MCP servers
    for i, server in enumerate(st.session_state.mcp_servers):
        status = st.session_state.mcp_statuses.get(server["name"], "unknown")
        enabled_class = "enabled" if server["enabled"] else "disabled"
        
        with st.container():
            col1, col2, col3 = st.columns([3, 1, 1])
            
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
                toggle_label = "✓" if server["enabled"] else "○"
                if st.button(toggle_label, key=f"toggle_{i}", help="Toggle server"):
                    toggle_mcp_server(i)
                    st.rerun()
            
            with col3:
                # Remove button (only for non-default servers)
                if i >= len(DEFAULT_MCP_SERVERS):
                    if st.button("🗑️", key=f"remove_{i}", help="Remove server"):
                        remove_mcp_server(i)
                        st.rerun()
    
    # Add new MCP server
    st.markdown("---")
    if st.button("➕ Add MCP Server", use_container_width=True):
        st.session_state.show_add_mcp = not st.session_state.show_add_mcp
    
    if st.session_state.show_add_mcp:
        with st.form("add_mcp_form"):
            st.markdown("**Add New MCP Server**")
            new_name = st.text_input("Name", placeholder="My MCP Server")
            new_url = st.text_input("URL", placeholder="http://service:8000")
            new_desc = st.text_input("Description", placeholder="What does this server do?")
            new_icon = st.selectbox("Icon", ["🔧", "📊", "🔍", "💾", "🌐", "📁", "🔒", "⚡"])
            
            if st.form_submit_button("Add Server"):
                if new_name and new_url:
                    add_mcp_server(new_name, new_url, new_desc, new_icon)
                    st.session_state.show_add_mcp = False
                    st.success(f"Added {new_name}!")
                    st.rerun()
                else:
                    st.error("Name and URL are required")
    
    st.markdown("---")
    
    # Tools section
    st.markdown("### 🛠️ Available Tools")
    
    if st.button("🔄 Refresh Tools", use_container_width=True):
        st.session_state.mcp_tools = get_available_tools()
        if st.session_state.mcp_tools:
            st.success(f"Found {len(st.session_state.mcp_tools)} tools!")
        else:
            st.warning("No tools found")
    
    if st.session_state.mcp_tools:
        # Group tools by prefix
        tool_groups = {}
        for tool in st.session_state.mcp_tools:
            tool_name = tool.get("name", tool.get("identifier", "Unknown"))
            # Try to extract group from tool name
            if "::" in tool_name:
                group = tool_name.split("::")[0]
            elif "_" in tool_name:
                group = tool_name.split("_")[0]
            else:
                group = "Other"
            
            if group not in tool_groups:
                tool_groups[group] = []
            tool_groups[group].append(tool)
        
        for group, tools in tool_groups.items():
            with st.expander(f"📦 {group} ({len(tools)} tools)"):
                for tool in tools:
                    tool_name = tool.get("name", tool.get("identifier", "Unknown"))
                    st.caption(f"• {tool_name}")
    else:
        st.info("Click 'Refresh Tools' to load")
    
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
    enabled_servers = [s for s in st.session_state.mcp_servers if s["enabled"]]
    
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
    
    # Server details
    cols = st.columns(len(enabled_servers) if enabled_servers else 1)
    for i, server in enumerate(enabled_servers):
        with cols[i]:
            status = st.session_state.mcp_statuses.get(server["name"], "unknown")
            status_color = "#10b981" if status == "online" else "#ef4444" if status == "offline" else "#f59e0b"
            st.markdown(f"""
            <div style="background: #1e293b; border-radius: 8px; padding: 0.75rem; text-align: center;">
                <div style="font-size: 1.5rem;">{server['icon']}</div>
                <div style="font-weight: 600; color: #f1f5f9;">{server['name']}</div>
                <div style="font-size: 0.7rem; color: {status_color};">● {status}</div>
            </div>
            """, unsafe_allow_html=True)

# Metrics
col1, col2, col3, col4 = st.columns(4)
with col1:
    st.metric("💬 Messages", len(st.session_state.messages))
with col2:
    st.metric("🔧 Tool Calls", st.session_state.tool_calls_count)
with col3:
    enabled_count = len([s for s in st.session_state.mcp_servers if s["enabled"]])
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
if prompt := st.chat_input("Ask a question... (e.g., 'What's the weather at VIDP?' or 'Check vacation balance for EMP001')"):
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
enabled_servers = [s["name"] for s in st.session_state.mcp_servers if s["enabled"]]
st.markdown(f"""
<div style="text-align: center; color: #64748b; font-size: 0.8rem;">
    <p>🦙 LlamaStack Multi-MCP Demo | Model: {MODEL_ID}</p>
    <p>Active MCP Servers: {', '.join(enabled_servers) if enabled_servers else 'None'}</p>
</div>
""", unsafe_allow_html=True)
