#!/bin/bash
# Multi-Project Demo Setup
#
# Creates multiple namespaces with different LlamaStack configurations
# to demonstrate how different teams get different MCP servers.
#
# Usage:
#   ./setup-multi-project.sh           # Setup all projects
#   ./setup-multi-project.sh status    # Show status of all projects
#   ./setup-multi-project.sh cleanup   # Remove demo projects

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

# Hardcoded project namespaces for quick demo setup
NS_HR="team-hr"
NS_DEV="team-dev"
NS_OPS="team-ops"

print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BLUE}🦙 LlamaStack Multi-Project Demo${NC}"
    echo -e "${CYAN}║${NC}  Demonstrating different LlamaStack distributions per project"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

deploy_to_namespace() {
    local ns=$1
    local phase=$2
    local desc=$3
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📁 $ns${NC} - $desc"
    
    # Create namespace if needed
    oc get namespace "$ns" &>/dev/null || oc new-project "$ns" 2>/dev/null || oc create namespace "$ns"
    
    # Apply manifests directly with namespace substitution (faster than switching projects)
    echo -e "   Deploying $phase..."
    sed "s/my-first-model/$ns/g" "$MANIFEST_DIR/$phase/deploy-$phase.yaml" | oc apply -f - 2>&1 | grep -E "created|configured|unchanged" | head -5 | sed 's/^/   /'
    echo -e "   ${GREEN}✓ Done${NC}"
    echo ""
}

setup_projects() {
    print_header
    
    echo -e "${BLUE}Setting up multi-project demo...${NC}"
    echo ""
    
    # Deploy all projects in parallel-ish (apply manifests directly)
    deploy_to_namespace "$NS_HR" "phase2" "HR Team - Weather + HR tools"
    deploy_to_namespace "$NS_DEV" "full" "Dev Team - All development tools"
    deploy_to_namespace "$NS_OPS" "phase1" "Ops Team - Weather only"
    
    echo -e "${GREEN}✅ Multi-project demo setup complete!${NC}"
    echo ""
    echo -e "${YELLOW}⏳ Wait ~60s for pods to start, then run:${NC}"
    echo "   $0 status"
    echo ""
}

show_project_status() {
    local ns=$1
    local desc=$2
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📁 $ns${NC} - $desc"
    
    if ! oc get namespace "$ns" &>/dev/null; then
        echo -e "   ${YELLOW}⚠ Not deployed${NC}"
        return
    fi
    
    # Check LlamaStack pod
    LS_POD=$(oc get pods -n "$ns" -l app=lsd-genai-playground -o name 2>/dev/null | head -1)
    if [ -n "$LS_POD" ]; then
        LS_STATUS=$(oc get "$LS_POD" -n "$ns" -o jsonpath='{.status.phase}' 2>/dev/null)
        echo -e "   LlamaStack: ${GREEN}$LS_STATUS${NC}"
    else
        echo -e "   LlamaStack: ${RED}Not running${NC}"
    fi
    
    # Count MCP servers from config
    MCP_COUNT=$(oc get configmap llama-stack-config -n "$ns" -o jsonpath='{.data.run\.yaml}' 2>/dev/null | grep -c "toolgroup_id: mcp::" || echo "0")
    echo -e "   MCP Servers: ${GREEN}$MCP_COUNT${NC}"
    
    # Get tools count if running
    if [ -n "$LS_POD" ] && [ "$LS_STATUS" = "Running" ]; then
        TOOLS=$(oc exec "$LS_POD" -n "$ns" -- curl -s http://localhost:8321/v1/tools 2>/dev/null | python3 -c "
import sys,json
try:
    data=json.load(sys.stdin)
    tools = [t['name'] for t in data.get('data',[]) if 'mcp::' in t.get('toolgroup_id','')]
    print(f'{len(tools)} tools: {', '.join(tools[:5])}{'...' if len(tools)>5 else ''}')
except:
    print('?')
" 2>/dev/null || echo "?")
        echo -e "   Tools: ${GREEN}$TOOLS${NC}"
    fi
    
    # Get frontend URL
    ROUTE=$(oc get route llamastack-multi-mcp-demo -n "$ns" -o jsonpath='{.spec.host}' 2>/dev/null)
    [ -n "$ROUTE" ] && echo -e "   URL: ${GREEN}https://$ROUTE${NC}"
    echo ""
}

show_status() {
    print_header
    
    echo -e "${BLUE}📊 Project Status${NC}"
    echo ""
    
    show_project_status "$NS_HR" "HR Team - Weather + HR tools"
    show_project_status "$NS_DEV" "Dev Team - All development tools"
    show_project_status "$NS_OPS" "Ops Team - Weather only"
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}💡 Demo Commands:${NC}"
    echo "  oc project $NS_HR && ./scripts/deploy.sh tools"
    echo "  oc project $NS_DEV && ./scripts/deploy.sh tools"
    echo "  oc project $NS_OPS && ./scripts/deploy.sh tools"
    echo ""
}

compare_project() {
    local ns=$1
    local desc=$2
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📁 $ns${NC} - $desc"
    
    if ! oc get namespace "$ns" &>/dev/null; then
        echo -e "   ${YELLOW}⚠ Not deployed${NC}"
        return
    fi
    
    echo -e "   ${CYAN}MCP Toolgroups:${NC}"
    oc get configmap llama-stack-config -n "$ns" -o jsonpath='{.data.run\.yaml}' 2>/dev/null | \
        grep "toolgroup_id: mcp::" | sed 's/^/   /' || echo "   None"
    
    echo -e "   ${CYAN}Tools:${NC}"
    oc exec deployment/lsd-genai-playground -n "$ns" -- curl -s http://localhost:8321/v1/tools 2>/dev/null | \
        python3 -c "
import sys,json
try:
    data=json.load(sys.stdin)
    groups = {}
    for t in data.get('data', []):
        g = t.get('toolgroup_id', '')
        if 'mcp::' in g:
            groups.setdefault(g, []).append(t['name'])
    for g, tools in sorted(groups.items()):
        print(f'   {g}: {', '.join(tools)}')
except:
    print('   (not running)')
" 2>/dev/null || echo "   (not running)"
    echo ""
}

compare_projects() {
    print_header
    
    echo -e "${BLUE}🔍 Comparing Project Configurations${NC}"
    echo ""
    
    compare_project "$NS_HR" "HR Team"
    compare_project "$NS_DEV" "Dev Team"
    compare_project "$NS_OPS" "Ops Team"
}

cleanup_projects() {
    print_header
    
    echo -e "${YELLOW}⚠ This will delete:${NC}"
    echo "  - $NS_HR"
    echo "  - $NS_DEV"
    echo "  - $NS_OPS"
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

# Main
case "${1:-setup}" in
    setup)
        setup_projects
        ;;
    status)
        show_status
        ;;
    compare)
        compare_projects
        ;;
    cleanup)
        cleanup_projects
        ;;
    help|--help|-h)
        print_header
        echo "Usage: $0 [command]"
        echo ""
        echo "Commands:"
        echo "  setup     Create and configure all demo projects (default)"
        echo "  status    Show status of all demo projects"
        echo "  compare   Compare MCP configurations across projects"
        echo "  cleanup   Delete all demo projects"
        echo ""
        echo "Hardcoded namespaces:"
        echo "  - $NS_HR (phase2): HR Team - Weather + HR tools"
        echo "  - $NS_DEV (full): Dev Team - All development tools"
        echo "  - $NS_OPS (phase1): Ops Team - Weather only"
        echo ""
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo "Run '$0 help' for usage"
        exit 1
        ;;
esac
