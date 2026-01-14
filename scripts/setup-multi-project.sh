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

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

# Project configurations
# Format: "namespace:phase:description"
PROJECTS=(
    "team-hr:phase2:HR Team - Weather + HR tools"
    "team-dev:full:Dev Team - All development tools"
    "team-ops:phase1:Ops Team - Weather only (minimal)"
)

print_header() {
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}  ${BLUE}🦙 LlamaStack Multi-Project Demo${NC}"
    echo -e "${CYAN}║${NC}  Demonstrating different LlamaStack distributions per project"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

setup_projects() {
    print_header
    
    echo -e "${BLUE}Setting up multi-project demo...${NC}"
    echo ""
    
    for project_config in "${PROJECTS[@]}"; do
        IFS=':' read -r namespace phase description <<< "$project_config"
        
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}📁 Project: ${GREEN}$namespace${NC}"
        echo -e "   ${description}"
        echo ""
        
        # Create namespace if it doesn't exist
        if ! oc get namespace "$namespace" &>/dev/null; then
            echo -e "   Creating namespace..."
            oc new-project "$namespace" --display-name="$description" 2>/dev/null || \
                oc create namespace "$namespace"
        else
            echo -e "   Namespace exists, switching to it..."
        fi
        
        oc project "$namespace" >/dev/null
        
        # Deploy the appropriate phase
        echo -e "   Deploying $phase..."
        "$SCRIPT_DIR/deploy.sh" "$phase" 2>&1 | sed 's/^/   /'
        
        echo ""
    done
    
    echo -e "${GREEN}✅ Multi-project demo setup complete!${NC}"
    echo ""
    show_status
}

show_status() {
    print_header
    
    echo -e "${BLUE}📊 Project Status${NC}"
    echo ""
    
    for project_config in "${PROJECTS[@]}"; do
        IFS=':' read -r namespace phase description <<< "$project_config"
        
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}📁 $namespace${NC} - $description"
        echo ""
        
        if ! oc get namespace "$namespace" &>/dev/null; then
            echo -e "   ${YELLOW}⚠ Namespace not found${NC}"
            continue
        fi
        
        # Check LlamaStack pod
        LS_POD=$(oc get pods -n "$namespace" -l app=lsd-genai-playground -o name 2>/dev/null | head -1)
        if [ -n "$LS_POD" ]; then
            LS_STATUS=$(oc get "$LS_POD" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null)
            echo -e "   LlamaStack: ${GREEN}$LS_STATUS${NC}"
        else
            echo -e "   LlamaStack: ${RED}Not deployed${NC}"
        fi
        
        # Count MCP servers
        MCP_COUNT=$(oc get configmap llama-stack-config -n "$namespace" -o jsonpath='{.data.run\.yaml}' 2>/dev/null | grep -c "toolgroup_id: mcp::" || echo "0")
        echo -e "   MCP Servers: ${GREEN}$MCP_COUNT${NC}"
        
        # Get tools count
        if [ -n "$LS_POD" ] && [ "$LS_STATUS" = "Running" ]; then
            TOOLS_COUNT=$(oc exec "$LS_POD" -n "$namespace" -- curl -s http://localhost:8321/v1/tools 2>/dev/null | python3 -c "import sys,json; data=json.load(sys.stdin); print(len(data.get('data',[])))" 2>/dev/null || echo "?")
            echo -e "   Tools: ${GREEN}$TOOLS_COUNT${NC}"
        fi
        
        # Get frontend URL
        ROUTE=$(oc get route llamastack-multi-mcp-demo -n "$namespace" -o jsonpath='{.spec.host}' 2>/dev/null)
        if [ -n "$ROUTE" ]; then
            echo -e "   Frontend: ${GREEN}https://$ROUTE${NC}"
        fi
        
        echo ""
    done
    
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${BLUE}💡 Demo Commands:${NC}"
    echo ""
    echo "  # Switch between projects and compare tools:"
    echo "  oc project team-hr && ./scripts/deploy.sh tools"
    echo "  oc project team-dev && ./scripts/deploy.sh tools"
    echo ""
    echo "  # Compare configurations:"
    echo "  oc project team-hr && ./scripts/deploy.sh config"
    echo "  oc project team-dev && ./scripts/deploy.sh config"
    echo ""
}

compare_projects() {
    print_header
    
    echo -e "${BLUE}🔍 Comparing Project Configurations${NC}"
    echo ""
    
    for project_config in "${PROJECTS[@]}"; do
        IFS=':' read -r namespace phase description <<< "$project_config"
        
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${BLUE}📁 $namespace${NC} ($phase)"
        echo ""
        
        if ! oc get namespace "$namespace" &>/dev/null; then
            echo -e "   ${YELLOW}⚠ Namespace not found${NC}"
            continue
        fi
        
        echo -e "   ${CYAN}MCP Toolgroups:${NC}"
        oc get configmap llama-stack-config -n "$namespace" -o jsonpath='{.data.run\.yaml}' 2>/dev/null | \
            grep "toolgroup_id: mcp::" | sed 's/^/   /' || echo "   None configured"
        
        echo ""
        echo -e "   ${CYAN}Available Tools:${NC}"
        oc exec deployment/lsd-genai-playground -n "$namespace" -- curl -s http://localhost:8321/v1/tools 2>/dev/null | \
            python3 -c "
import sys,json
try:
    data=json.load(sys.stdin)
    tools = data.get('data', [])
    groups = {}
    for t in tools:
        g = t.get('toolgroup_id', 'builtin')
        if 'mcp::' in g:
            if g not in groups:
                groups[g] = []
            groups[g].append(t['name'])
    for g, tlist in sorted(groups.items()):
        print(f'   {g}: {len(tlist)} tools')
except:
    print('   Could not fetch tools')
" 2>/dev/null || echo "   Could not fetch tools"
        
        echo ""
    done
}

cleanup_projects() {
    print_header
    
    echo -e "${YELLOW}⚠ This will delete the following namespaces:${NC}"
    for project_config in "${PROJECTS[@]}"; do
        IFS=':' read -r namespace phase description <<< "$project_config"
        echo "  - $namespace"
    done
    echo ""
    
    read -p "Are you sure? (y/N) " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for project_config in "${PROJECTS[@]}"; do
            IFS=':' read -r namespace phase description <<< "$project_config"
            echo -e "Deleting ${RED}$namespace${NC}..."
            oc delete namespace "$namespace" --ignore-not-found=true
        done
        echo ""
        echo -e "${GREEN}✅ Cleanup complete${NC}"
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
        echo "Projects that will be created:"
        for project_config in "${PROJECTS[@]}"; do
            IFS=':' read -r namespace phase description <<< "$project_config"
            echo "  - $namespace ($phase): $description"
        done
        echo ""
        ;;
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo "Run '$0 help' for usage"
        exit 1
        ;;
esac
