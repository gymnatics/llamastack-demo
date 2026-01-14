#!/bin/bash
# Multi-Project Demo Setup
#
# Demonstrates how different teams/projects can have different LlamaStack distributions
# with different MCP server configurations, all sharing the same model endpoint.
#
# Architecture:
#   - Model serving (vLLM/GPU) runs in the source namespace
#   - Each team gets their own namespace with their own LlamaStack + MCP servers
#   - All LlamaStacks point to the shared model endpoint (cross-namespace access)
#
# Usage:
#   ./setup-multi-project.sh setup     # Create all team namespaces
#   ./setup-multi-project.sh status    # Show status of all teams
#   ./setup-multi-project.sh cleanup   # Delete team namespaces
#   ./setup-multi-project.sh hr        # Switch current ns to HR config
#   ./setup-multi-project.sh dev       # Switch current ns to Dev config
#   ./setup-multi-project.sh ops       # Switch current ns to Ops config

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$(dirname "$SCRIPT_DIR")/manifests"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Team namespaces (hardcoded for quick demo)
NS_HR="team-hr"
NS_DEV="team-dev"
NS_OPS="team-ops"

# Get current namespace
CURRENT_NS=$(oc project -q 2>/dev/null || echo "my-first-model")

# Auto-detect model endpoint from existing LlamaStack config
detect_model_endpoint() {
    local ns="${1:-$CURRENT_NS}"
    
    # Try to get from existing LlamaStack config
    local endpoint=$(oc get configmap llama-stack-config -n "$ns" -o jsonpath='{.data.run\.yaml}' 2>/dev/null | \
        grep -A5 "provider_type: remote::vllm" | grep "url:" | head -1 | sed 's/.*url: //' | tr -d ' ')
    
    if [ -n "$endpoint" ]; then
        echo "$endpoint"
        return
    fi
    
    # Try my-first-model namespace
    endpoint=$(oc get configmap llama-stack-config -n "my-first-model" -o jsonpath='{.data.run\.yaml}' 2>/dev/null | \
        grep -A5 "provider_type: remote::vllm" | grep "url:" | head -1 | sed 's/.*url: //' | tr -d ' ')
    
    if [ -n "$endpoint" ]; then
        echo "$endpoint"
        return
    fi
    
    echo ""
}

MODEL_ENDPOINT="${MODEL_ENDPOINT:-$(detect_model_endpoint)}"
NS_MODEL=$(echo "$MODEL_ENDPOINT" | sed -n 's/.*-predictor\.\([^.]*\)\.svc.*/\1/p')

print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BLUE}🦙 LlamaStack Multi-Project Demo${NC}"
    if [ -n "$NS_MODEL" ]; then
        echo -e "${CYAN}║${NC}  Model namespace: ${GREEN}$NS_MODEL${NC}"
    fi
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

deploy_team() {
    local ns=$1
    local phase=$2
    local desc=$3
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📁 $ns${NC} - $desc"
    
    # Check if model endpoint was detected
    if [ -z "$MODEL_ENDPOINT" ]; then
        echo -e "   ${RED}❌ No model endpoint detected!${NC}"
        echo -e "   ${YELLOW}Set MODEL_ENDPOINT env var or ensure LlamaStack config exists${NC}"
        return 1
    fi
    
    # Create namespace if needed
    if ! oc get namespace "$ns" &>/dev/null; then
        echo -e "   Creating namespace..."
        oc new-project "$ns" 2>/dev/null || oc create namespace "$ns"
    else
        oc project "$ns" >/dev/null 2>&1
    fi
    
    # Deploy MCP servers and LlamaStack config for this phase
    echo -e "   Deploying $phase configuration..."
    
    local manifest_file="$MANIFEST_DIR/$phase/deploy-$phase.yaml"
    if [ ! -f "$manifest_file" ]; then
        echo -e "   ${RED}❌ Manifest not found: $manifest_file${NC}"
        return 1
    fi
    
    # Replace namespace patterns and ensure model endpoint points to source namespace
    sed -e "s/llamastack-$phase/$ns/g" \
        -e "s/my-first-model/$ns/g" \
        "$manifest_file" | \
        sed "s|\(llama-32-3b-instruct-predictor\)\.$ns\.|\1.$NS_MODEL.|g" | \
        oc apply -f - 2>&1 | grep -cE "created|configured|unchanged" | xargs -I {} echo "   {} resources applied"
    
    echo -e "   ${GREEN}✓ Done${NC}"
    echo ""
}

setup_all() {
    print_header
    
    if [ -z "$MODEL_ENDPOINT" ]; then
        echo -e "${RED}❌ Could not detect model endpoint!${NC}"
        echo ""
        echo "Please set MODEL_ENDPOINT environment variable:"
        echo "  export MODEL_ENDPOINT=http://your-model-predictor.namespace.svc.cluster.local:8080/v1"
        echo "  $0 setup"
        echo ""
        exit 1
    fi
    
    echo -e "${BLUE}Setting up multi-project demo...${NC}"
    echo -e "   Model endpoint: ${GREEN}$MODEL_ENDPOINT${NC}"
    echo ""
    
    deploy_team "$NS_HR" "phase2" "HR Team - Weather + HR tools"
    deploy_team "$NS_DEV" "full" "Dev Team - All development tools"
    deploy_team "$NS_OPS" "phase1" "Ops Team - Weather only"
    
    # Switch back to original namespace
    oc project "$CURRENT_NS" >/dev/null 2>&1
    
    echo -e "${GREEN}✅ Multi-project demo setup complete!${NC}"
    echo ""
    echo -e "${YELLOW}⏳ Wait ~60s for pods to start, then run:${NC}"
    echo "   $0 status"
    echo ""
}

show_team_status() {
    local ns=$1
    local desc=$2
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📁 $ns${NC} - $desc"
    
    if ! oc get namespace "$ns" &>/dev/null; then
        echo -e "   ${YELLOW}⚠ Not deployed${NC}"
        return
    fi
    
    # Count MCP servers from config
    MCP_COUNT=$(oc get configmap llama-stack-config -n "$ns" -o jsonpath='{.data.run\.yaml}' 2>/dev/null | grep -c "toolgroup_id: mcp::" || echo "0")
    echo -e "   MCP Servers: ${GREEN}$MCP_COUNT${NC}"
    
    # Check pods
    PODS=$(oc get pods -n "$ns" --no-headers 2>/dev/null | wc -l | tr -d ' ')
    RUNNING=$(oc get pods -n "$ns" --no-headers 2>/dev/null | grep -c "Running" || echo "0")
    echo -e "   Pods: ${GREEN}$RUNNING/$PODS running${NC}"
    
    # Get frontend URL
    ROUTE=$(oc get route llamastack-multi-mcp-demo -n "$ns" -o jsonpath='{.spec.host}' 2>/dev/null)
    [ -n "$ROUTE" ] && echo -e "   URL: ${GREEN}https://$ROUTE${NC}"
    echo ""
}

show_status() {
    print_header
    
    echo -e "${BLUE}📊 Team Status${NC}"
    echo ""
    
    show_team_status "$NS_OPS" "Ops Team - Weather only"
    show_team_status "$NS_HR" "HR Team - Weather + HR tools"
    show_team_status "$NS_DEV" "Dev Team - All development tools"
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}💡 Demo Commands:${NC}"
    echo "   oc project $NS_OPS && ./scripts/deploy.sh tools   # 3 tools"
    echo "   oc project $NS_HR && ./scripts/deploy.sh tools    # 10 tools"
    echo "   oc project $NS_DEV && ./scripts/deploy.sh tools   # 20+ tools"
    echo ""
}

cleanup_all() {
    print_header
    
    echo -e "${YELLOW}⚠ This will delete:${NC}"
    echo "   - $NS_HR"
    echo "   - $NS_DEV"
    echo "   - $NS_OPS"
    echo ""
    
    read -p "Are you sure? (y/N) " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "Deleting namespaces..."
        oc delete namespace "$NS_HR" "$NS_DEV" "$NS_OPS" --ignore-not-found=true 2>/dev/null &
        echo -e "${GREEN}✅ Cleanup started (runs in background)${NC}"
    else
        echo "Cancelled."
    fi
}

switch_config() {
    local team=$1
    local phase=$2
    local desc=$3
    
    print_header
    
    echo -e "${BLUE}▶ Switching to ${GREEN}$team${BLUE} configuration...${NC}"
    echo -e "   $desc"
    echo ""
    
    local config_file="$MANIFEST_DIR/llamastack/llama-stack-config-$phase.yaml"
    
    if [ ! -f "$config_file" ]; then
        echo -e "${RED}❌ Config file not found: $config_file${NC}"
        exit 1
    fi
    
    sed "s/my-first-model/$CURRENT_NS/g" "$config_file" > /tmp/llama-config.yaml
    oc create configmap llama-stack-config --from-file=run.yaml=/tmp/llama-config.yaml -n "$CURRENT_NS" --dry-run=client -o yaml | oc apply -f -
    rm /tmp/llama-config.yaml
    
    echo -e "   Restarting LlamaStack..."
    oc delete pod -l app=lsd-genai-playground -n "$CURRENT_NS" 2>/dev/null || true
    
    echo ""
    echo -e "${GREEN}✅ Switched to $team configuration!${NC}"
    echo -e "${YELLOW}⏳ Wait ~30s then run: ./scripts/deploy.sh tools${NC}"
    echo ""
}

# Main
case "${1:-help}" in
    setup)
        setup_all
        ;;
    status)
        show_status
        ;;
    cleanup)
        cleanup_all
        ;;
    hr)
        switch_config "HR Team" "phase2" "Weather + HR tools"
        ;;
    dev)
        switch_config "Dev Team" "full" "All 4 MCP servers"
        ;;
    ops)
        switch_config "Ops Team" "phase1" "Weather only"
        ;;
    help|--help|-h)
        print_header
        echo "Usage: $0 [command]"
        echo ""
        echo -e "${CYAN}Multi-Namespace Setup:${NC}"
        echo "  setup     Create team namespaces ($NS_HR, $NS_DEV, $NS_OPS)"
        echo "  status    Show status of all team namespaces"
        echo "  cleanup   Delete all team namespaces"
        echo ""
        echo -e "${CYAN}Config Switching (current namespace):${NC}"
        echo "  ops       Switch to Ops config (Weather only)"
        echo "  hr        Switch to HR config (Weather + HR)"
        echo "  dev       Switch to Dev config (All 4 MCPs)"
        echo ""
        echo -e "${CYAN}Model Endpoint:${NC}"
        if [ -n "$MODEL_ENDPOINT" ]; then
            echo "  Auto-detected: $MODEL_ENDPOINT"
        else
            echo "  Not detected - set MODEL_ENDPOINT env var"
        fi
        echo ""
        echo -e "${CYAN}Demo Flow (Multi-Namespace):${NC}"
        echo "  1. $0 setup                              # Create all teams"
        echo "  2. $0 status                             # Check status"
        echo "  3. oc project team-ops && ./scripts/deploy.sh tools  # 3 tools"
        echo "  4. oc project team-hr && ./scripts/deploy.sh tools   # 10 tools"
        echo "  5. oc project team-dev && ./scripts/deploy.sh tools  # 20+ tools"
        echo ""
        echo -e "${CYAN}Demo Flow (Config Switching):${NC}"
        echo "  1. $0 ops && sleep 30 && ./scripts/deploy.sh tools   # 3 tools"
        echo "  2. $0 hr && sleep 30 && ./scripts/deploy.sh tools    # 10 tools"
        echo "  3. $0 dev && sleep 30 && ./scripts/deploy.sh tools   # 20+ tools"
        echo ""
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo "Run '$0 help' for usage"
        exit 1
        ;;
esac
