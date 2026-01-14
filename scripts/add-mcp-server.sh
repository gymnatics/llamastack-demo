#!/bin/bash
# Script to add MCP servers to LlamaStack Distribution via YAML
# This demonstrates the YAML-based approach to managing MCP servers

set -e

NAMESPACE="my-first-model"
RHOAI_NAMESPACE="redhat-ods-applications"

echo "=============================================="
echo "  LlamaStack MCP Server Management Script"
echo "=============================================="
echo ""

# Function to show current configuration
show_current_config() {
    echo "📋 Current LlamaStack MCP Configuration:"
    echo "----------------------------------------"
    oc get configmap llama-stack-config -n $NAMESPACE -o jsonpath='{.data.run\.yaml}' 2>/dev/null | grep -A3 "toolgroup_id: mcp::" || echo "No MCP servers configured"
    echo ""
    echo "📋 Current AI Assets (MCP Servers in OpenShift AI):"
    echo "---------------------------------------------------"
    oc get configmap gen-ai-aa-mcp-servers -n $RHOAI_NAMESPACE -o jsonpath='{.data}' 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); [print(f'  - {k}') for k in d.keys()]" || echo "No AI Assets configured"
    echo ""
}

# Function to apply Phase 1 (Weather only)
apply_phase1() {
    echo "🌤️  Applying Phase 1: Weather MCP Server only"
    echo "----------------------------------------------"
    
    # Apply LlamaStack config
    oc create configmap llama-stack-config \
        --from-file=run.yaml=/Users/dayeo/LlamaStack-MCP-Demo/manifests/llamastack/llama-stack-config-phase1.yaml \
        -n $NAMESPACE \
        --dry-run=client -o yaml | oc apply -f -
    
    # Apply AI Assets
    oc apply -f /Users/dayeo/LlamaStack-MCP-Demo/manifests/mcp-servers/ai-assets-phase1.yaml
    
    # Restart LlamaStack
    echo "🔄 Restarting LlamaStack..."
    oc delete pod -l app=lsd-genai-playground -n $NAMESPACE
    
    echo "✅ Phase 1 applied! Weather MCP server is now the only MCP server."
    echo ""
}

# Function to apply Phase 2 (Weather + HR)
apply_phase2() {
    echo "👥 Applying Phase 2: Weather + HR MCP Servers"
    echo "----------------------------------------------"
    
    # Apply LlamaStack config
    oc create configmap llama-stack-config \
        --from-file=run.yaml=/Users/dayeo/LlamaStack-MCP-Demo/manifests/llamastack/llama-stack-config-phase2.yaml \
        -n $NAMESPACE \
        --dry-run=client -o yaml | oc apply -f -
    
    # Apply AI Assets
    oc apply -f /Users/dayeo/LlamaStack-MCP-Demo/manifests/mcp-servers/ai-assets-phase2.yaml
    
    # Restart LlamaStack
    echo "🔄 Restarting LlamaStack..."
    oc delete pod -l app=lsd-genai-playground -n $NAMESPACE
    
    echo "✅ Phase 2 applied! HR MCP server has been added."
    echo ""
}

# Function to apply Full config (all 4 MCP servers)
apply_full() {
    echo "🚀 Applying Full Configuration: All 4 MCP Servers"
    echo "--------------------------------------------------"
    
    # Apply LlamaStack config
    oc create configmap llama-stack-config \
        --from-file=run.yaml=/Users/dayeo/LlamaStack-MCP-Demo/manifests/llamastack/llama-stack-config-full.yaml \
        -n $NAMESPACE \
        --dry-run=client -o yaml | oc apply -f -
    
    # Apply AI Assets
    oc apply -f /Users/dayeo/LlamaStack-MCP-Demo/manifests/mcp-servers/ai-assets-full.yaml
    
    # Restart LlamaStack
    echo "🔄 Restarting LlamaStack..."
    oc delete pod -l app=lsd-genai-playground -n $NAMESPACE
    
    echo "✅ Full configuration applied! All 4 MCP servers are now active:"
    echo "   - Weather (OpenWeatherMap)"
    echo "   - HR Tools"
    echo "   - Jira/Confluence"
    echo "   - GitHub"
    echo ""
}

# Function to verify tools
verify_tools() {
    echo "🔍 Verifying available tools..."
    echo "-------------------------------"
    sleep 30  # Wait for LlamaStack to restart
    
    oc exec deployment/lsd-genai-playground -n $NAMESPACE -- \
        curl -s http://localhost:8321/v1/tools 2>/dev/null | \
        python3 -c "import sys,json; data=json.load(sys.stdin); tools=[t['name'] for t in data.get('data',[])]; print(f'Total tools: {len(tools)}'); [print(f'  - {t}') for t in tools]"
    echo ""
}

# Main menu
echo "Select an option:"
echo "  1) Show current configuration"
echo "  2) Apply Phase 1 (Weather only)"
echo "  3) Apply Phase 2 (Weather + HR)"
echo "  4) Apply Full (All 4 MCP servers)"
echo "  5) Verify available tools"
echo "  q) Quit"
echo ""

read -p "Enter choice [1-5, q]: " choice

case $choice in
    1) show_current_config ;;
    2) apply_phase1 ;;
    3) apply_phase2 ;;
    4) apply_full ;;
    5) verify_tools ;;
    q|Q) echo "Goodbye!" ;;
    *) echo "Invalid choice" ;;
esac
