#!/usr/bin/env python3
"""
LlamaStack MCP Tool Test Script

This script tests LlamaStack connectivity and MCP tool calling.
Run this inside a pod in the cluster to test internal service connectivity.

Usage:
    python test_llamastack_mcp.py --project admin-workshop
    python test_llamastack_mcp.py --url http://lsd-genai-playground-service.admin-workshop.svc.cluster.local:8321
"""

import argparse
import json
import sys
import requests
from typing import Dict, List, Optional


def check_health(base_url: str) -> bool:
    """Check if LlamaStack is healthy."""
    try:
        response = requests.get(f"{base_url}/v1/health", timeout=10)
        if response.status_code == 200:
            print("✅ LlamaStack is healthy!")
            return True
        else:
            print(f"❌ Health check failed: {response.status_code}")
            return False
    except Exception as e:
        print(f"❌ Connection error: {e}")
        return False


def list_models(base_url: str) -> List[Dict]:
    """List available models."""
    try:
        response = requests.get(f"{base_url}/v1/models", timeout=10)
        if response.status_code == 200:
            models = response.json().get("data", [])
            llm_models = [m for m in models if m.get("model_type") == "llm"]
            print(f"\n🤖 LLM Models Available: {len(llm_models)}")
            print("=" * 50)
            for m in llm_models:
                print(f"  • {m.get('identifier')} ({m.get('provider_id')})")
            return llm_models
        else:
            print(f"❌ Error listing models: {response.status_code}")
            return []
    except Exception as e:
        print(f"❌ Error: {e}")
        return []


def list_tools(base_url: str) -> Dict[str, List[str]]:
    """List available tools grouped by MCP server."""
    try:
        response = requests.get(f"{base_url}/v1/tools", timeout=10)
        if response.status_code == 200:
            data = response.json()
            tools = data if isinstance(data, list) else data.get("data", [])
            
            # Group by toolgroup
            toolgroups = {}
            for t in tools:
                tg = t.get("toolgroup_id", "unknown")
                if tg not in toolgroups:
                    toolgroups[tg] = []
                toolgroups[tg].append(t.get("name", "unknown"))
            
            mcp_servers = [tg for tg in toolgroups.keys() if tg.startswith("mcp::")]
            
            print(f"\n🛠️ MCP Servers: {len(mcp_servers)}")
            print(f"📊 Total Tools: {len(tools)}")
            print("=" * 50)
            for tg, tool_list in sorted(toolgroups.items()):
                icon = "🌤️" if "weather" in tg else "👥" if "hr" in tg else "🔧"
                print(f"\n{icon} {tg} ({len(tool_list)} tools)")
                for tool in tool_list:
                    print(f"   • {tool}")
            
            return toolgroups
        else:
            print(f"❌ Error listing tools: {response.status_code}")
            return {}
    except Exception as e:
        print(f"❌ Error: {e}")
        return {}


def invoke_tool(base_url: str, tool_name: str, kwargs: Dict) -> Optional[str]:
    """Invoke a tool directly via LlamaStack."""
    try:
        print(f"\n🔧 Invoking tool: {tool_name}")
        print(f"   Parameters: {json.dumps(kwargs)}")
        
        response = requests.post(
            f"{base_url}/v1/tool-runtime/invoke",
            json={"tool_name": tool_name, "kwargs": kwargs},
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            content = result.get("content", [])
            if isinstance(content, list) and content:
                text = content[0].get("text", str(content))
            else:
                text = str(result)
            print(f"   ✅ Result: {text[:500]}...")
            return text
        else:
            print(f"   ❌ Error: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"   ❌ Error: {e}")
        return None


def test_chat_completion(base_url: str, model_id: str, message: str) -> Optional[str]:
    """Test basic chat completion."""
    try:
        print(f"\n💬 Testing chat completion")
        print(f"   Model: {model_id}")
        print(f"   Message: {message}")
        
        payload = {
            "model": model_id,
            "messages": [{"role": "user", "content": message}],
            "temperature": 0.7,
            "max_tokens": 256
        }
        
        response = requests.post(
            f"{base_url}/v1/openai/v1/chat/completions",
            json=payload,
            timeout=60
        )
        
        if response.status_code == 200:
            result = response.json()
            content = result.get("choices", [{}])[0].get("message", {}).get("content", "")
            print(f"   ✅ Response: {content[:300]}...")
            return content
        else:
            print(f"   ❌ Error: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"   ❌ Error: {e}")
        return None


def test_agent_with_tools(base_url: str, model_id: str, toolgroups: List[str], question: str) -> Optional[str]:
    """Test agent-based tool calling using LlamaStack Agents API."""
    try:
        print(f"\n🤖 Testing Agent with Tools")
        print(f"   Model: {model_id}")
        print(f"   Toolgroups: {toolgroups}")
        print(f"   Question: {question}")
        
        # Step 1: Create agent
        agent_config = {
            "agent_config": {
                "model": model_id,
                "instructions": "You are a helpful assistant. Use the available tools to answer questions.",
                "toolgroups": toolgroups,
                "enable_session_persistence": False
            }
        }
        
        response = requests.post(f"{base_url}/v1/agents", json=agent_config, timeout=30)
        if response.status_code != 200:
            print(f"   ❌ Error creating agent: {response.status_code} - {response.text}")
            return None
        
        agent_id = response.json().get("agent_id")
        print(f"   ✅ Agent created: {agent_id}")
        
        # Step 2: Create session
        session_response = requests.post(
            f"{base_url}/v1/agents/{agent_id}/session",
            json={"session_name": "test-session"},
            timeout=30
        )
        if session_response.status_code != 200:
            print(f"   ❌ Error creating session: {session_response.status_code}")
            return None
        
        session_id = session_response.json().get("session_id")
        print(f"   ✅ Session created: {session_id}")
        
        # Step 3: Ask question
        turn_request = {
            "messages": [{"role": "user", "content": question}],
            "stream": False
        }
        
        response = requests.post(
            f"{base_url}/v1/agents/{agent_id}/session/{session_id}/turn",
            json=turn_request,
            timeout=120
        )
        
        if response.status_code == 200:
            result = response.json()
            # Extract response
            for event in result.get("events", []):
                if event.get("event_type") == "turn_complete":
                    turn = event.get("turn", {})
                    for msg in turn.get("output_message", {}).get("content", []):
                        if msg.get("type") == "text":
                            text = msg.get("text", "")
                            print(f"   ✅ Response: {text[:500]}...")
                            
                            # Check for tool calls
                            tool_steps = [s for s in turn.get("steps", []) if s.get("step_type") == "tool_execution"]
                            if tool_steps:
                                print(f"   🔧 Tools used:")
                                for step in tool_steps:
                                    for tc in step.get("tool_calls", []):
                                        print(f"      • {tc.get('tool_name')}")
                            return text
            return None
        else:
            print(f"   ❌ Error: {response.status_code} - {response.text}")
            return None
    except Exception as e:
        print(f"   ❌ Error: {e}")
        return None


def main():
    parser = argparse.ArgumentParser(description="Test LlamaStack MCP connectivity")
    parser.add_argument("--project", "-p", help="OpenShift project name (e.g., admin-workshop)")
    parser.add_argument("--url", "-u", help="Full LlamaStack URL")
    parser.add_argument("--test-tools", action="store_true", help="Test direct tool invocation")
    parser.add_argument("--test-agent", action="store_true", help="Test agent-based tool calling")
    
    args = parser.parse_args()
    
    # Determine URL
    if args.url:
        base_url = args.url
    elif args.project:
        base_url = f"http://lsd-genai-playground-service.{args.project}.svc.cluster.local:8321"
    else:
        print("Error: Provide either --project or --url")
        sys.exit(1)
    
    print(f"🔗 LlamaStack URL: {base_url}")
    print("=" * 60)
    
    # Health check
    if not check_health(base_url):
        print("\n⚠️ LlamaStack is not healthy. Exiting.")
        sys.exit(1)
    
    # List models
    models = list_models(base_url)
    if not models:
        print("\n⚠️ No models found. Exiting.")
        sys.exit(1)
    
    model_id = models[0].get("identifier")
    
    # List tools
    toolgroups = list_tools(base_url)
    mcp_toolgroups = [tg for tg in toolgroups.keys() if tg.startswith("mcp::")]
    
    # Test chat completion
    test_chat_completion(base_url, model_id, "What is 2 + 2?")
    
    # Test direct tool invocation
    if args.test_tools and mcp_toolgroups:
        print("\n" + "=" * 60)
        print("🧪 Testing Direct Tool Invocation")
        print("=" * 60)
        
        # Test weather tools if available
        if any("weather" in tg for tg in mcp_toolgroups):
            invoke_tool(base_url, "get_weather_statistics", {})
            invoke_tool(base_url, "list_weather_stations", {})
        
        # Test HR tools if available
        if any("hr" in tg for tg in mcp_toolgroups):
            invoke_tool(base_url, "list_employees", {})
    
    # Test agent-based tool calling
    if args.test_agent and mcp_toolgroups:
        print("\n" + "=" * 60)
        print("🧪 Testing Agent-Based Tool Calling")
        print("=" * 60)
        
        test_agent_with_tools(
            base_url, 
            model_id, 
            mcp_toolgroups,
            "List all available weather stations"
        )
    
    print("\n" + "=" * 60)
    print("✅ Test complete!")
    print("=" * 60)


if __name__ == "__main__":
    main()
