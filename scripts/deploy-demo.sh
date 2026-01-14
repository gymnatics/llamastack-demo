#!/bin/bash
# LlamaStack MCP Demo - Multi-Phase Deployment Script
#
# This script deploys the demo in separate namespaces:
#   - llamastack-phase1: Weather MCP only
#   - llamastack-phase2: Weather + HR MCPs
#   - llamastack-full: All 4 MCP servers
#
# Each namespace has its own LlamaStack distribution
#
# Usage:
#   ./deploy-demo.sh [phase1|phase2|full|all|status|cleanup]
#

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$(dirname "$SCRIPT_DIR")/manifests"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
echo_success() { echo -e "${GREEN}✅ $1${NC}"; }
echo_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
echo_error() { echo -e "${RED}❌ $1${NC}"; }

# Check if logged in to OpenShift
check_login() {
    if ! oc whoami &>/dev/null; then
        echo_error "Not logged in to OpenShift. Please run 'oc login' first."
        exit 1
    fi
    echo_info "Logged in as: $(oc whoami)"
}

# Create namespaces
create_namespaces() {
    echo_info "Creating namespaces..."
    oc apply -f "$MANIFEST_DIR/namespaces/namespaces.yaml"
    echo_success "Namespaces created"
}

# Deploy Phase 1
deploy_phase1() {
    echo ""
    echo "=============================================="
    echo -e "${BLUE}  Phase 1: Weather MCP Server Only${NC}"
    echo "=============================================="
    echo ""
    
    create_namespaces
    
    echo_info "Deploying Phase 1 to llamastack-phase1..."
    oc apply -f "$MANIFEST_DIR/phase1/deploy-phase1.yaml"
    
    echo_info "Waiting for pods to be ready..."
    oc wait --for=condition=ready pod -l app=mcp-weather -n llamastack-phase1 --timeout=120s || true
    oc wait --for=condition=ready pod -l app=lsd-genai-playground -n llamastack-phase1 --timeout=180s || true
    
    ROUTE=$(oc get route llamastack-phase1 -n llamastack-phase1 -o jsonpath='{.spec.host}' 2>/dev/null || echo "pending")
    echo ""
    echo_success "Phase 1 deployed!"
    echo_info "LlamaStack URL: https://$ROUTE"
    echo_info "MCP Servers: Weather only"
    echo_info "Tools: getforecast"
}

# Deploy Phase 2
deploy_phase2() {
    echo ""
    echo "=============================================="
    echo -e "${BLUE}  Phase 2: Weather + HR MCP Servers${NC}"
    echo "=============================================="
    echo ""
    
    create_namespaces
    
    echo_info "Deploying Phase 2 to llamastack-phase2..."
    oc apply -f "$MANIFEST_DIR/phase2/deploy-phase2.yaml"
    
    echo_info "Waiting for pods to be ready..."
    oc wait --for=condition=ready pod -l app=mcp-weather -n llamastack-phase2 --timeout=120s || true
    oc wait --for=condition=ready pod -l app=hr-mcp-server -n llamastack-phase2 --timeout=180s || true
    oc wait --for=condition=ready pod -l app=lsd-genai-playground -n llamastack-phase2 --timeout=180s || true
    
    ROUTE=$(oc get route llamastack-phase2 -n llamastack-phase2 -o jsonpath='{.spec.host}' 2>/dev/null || echo "pending")
    echo ""
    echo_success "Phase 2 deployed!"
    echo_info "LlamaStack URL: https://$ROUTE"
    echo_info "MCP Servers: Weather, HR"
    echo_info "Tools: getforecast, get_vacation_balance, get_employee_info, list_employees, list_job_openings, create_vacation_request"
}

# Deploy Full
deploy_full() {
    echo ""
    echo "=============================================="
    echo -e "${BLUE}  Full: All 4 MCP Servers${NC}"
    echo "=============================================="
    echo ""
    
    create_namespaces
    
    # Check for GitHub token
    if [ -z "$GITHUB_TOKEN" ]; then
        echo_warning "GITHUB_TOKEN not set. GitHub MCP will use placeholder token."
        echo_info "To set: export GITHUB_TOKEN=ghp_your_token_here"
    else
        echo_info "Updating GitHub token secret..."
        oc create secret generic github-mcp-token \
            --from-literal=GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_TOKEN" \
            -n llamastack-full \
            --dry-run=client -o yaml | oc apply -f -
    fi
    
    echo_info "Deploying Full configuration to llamastack-full..."
    oc apply -f "$MANIFEST_DIR/full/deploy-full.yaml"
    
    echo_info "Waiting for pods to be ready (this may take a few minutes)..."
    oc wait --for=condition=ready pod -l app=mcp-weather -n llamastack-full --timeout=120s || true
    oc wait --for=condition=ready pod -l app=hr-mcp-server -n llamastack-full --timeout=180s || true
    oc wait --for=condition=ready pod -l app=jira-mcp-server -n llamastack-full --timeout=180s || true
    oc wait --for=condition=ready pod -l app=github-mcp-server -n llamastack-full --timeout=180s || true
    oc wait --for=condition=ready pod -l app=lsd-genai-playground -n llamastack-full --timeout=180s || true
    
    ROUTE=$(oc get route llamastack-full -n llamastack-full -o jsonpath='{.spec.host}' 2>/dev/null || echo "pending")
    echo ""
    echo_success "Full configuration deployed!"
    echo_info "LlamaStack URL: https://$ROUTE"
    echo_info "MCP Servers: Weather, HR, Jira/Confluence, GitHub"
}

# Show status
show_status() {
    echo ""
    echo "=============================================="
    echo -e "${BLUE}  LlamaStack MCP Demo Status${NC}"
    echo "=============================================="
    echo ""
    
    for ns in llamastack-phase1 llamastack-phase2 llamastack-full; do
        if oc get namespace $ns &>/dev/null; then
            echo -e "${GREEN}📦 $ns${NC}"
            echo "   Pods:"
            oc get pods -n $ns --no-headers 2>/dev/null | while read line; do
                echo "     $line"
            done
            ROUTE=$(oc get route -n $ns -o jsonpath='{.items[0].spec.host}' 2>/dev/null || echo "none")
            echo "   Route: https://$ROUTE"
            
            # Get tool count
            TOOLS=$(oc exec deployment/lsd-genai-playground -n $ns -- curl -s http://localhost:8321/v1/tools 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('data',[])))" 2>/dev/null || echo "?")
            echo "   Tools: $TOOLS"
            echo ""
        else
            echo -e "${YELLOW}📦 $ns - Not deployed${NC}"
            echo ""
        fi
    done
}

# Cleanup
cleanup() {
    echo ""
    echo "=============================================="
    echo -e "${RED}  Cleanup - Removing Demo${NC}"
    echo "=============================================="
    echo ""
    
    read -p "Are you sure you want to delete all demo namespaces? (y/N) " confirm
    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        for ns in llamastack-phase1 llamastack-phase2 llamastack-full; do
            if oc get namespace $ns &>/dev/null; then
                echo_info "Deleting namespace $ns..."
                oc delete namespace $ns --wait=false
            fi
        done
        echo_success "Cleanup initiated. Namespaces will be deleted in the background."
    else
        echo_info "Cleanup cancelled."
    fi
}

# ============================================
# Single Namespace MCP Management Commands
# For use with existing namespace (my-first-model)
# ============================================

EXISTING_NS="${NAMESPACE:-my-first-model}"

# Show current MCP config
show_mcp_config() {
    echo ""
    echo "=============================================="
    echo -e "${BLUE}  Current MCP Configuration${NC}"
    echo "  Namespace: $EXISTING_NS"
    echo "=============================================="
    echo ""
    
    echo_info "MCP Servers configured in LlamaStack:"
    oc get configmap llama-stack-config -n $EXISTING_NS -o jsonpath='{.data.run\.yaml}' 2>/dev/null | grep -A4 "toolgroup_id: mcp::" || echo "  None configured"
    
    echo ""
    echo_info "Available tools:"
    oc exec deployment/lsd-genai-playground -n $EXISTING_NS -- curl -s http://localhost:8321/v1/tools 2>/dev/null | python3 -c "
import sys,json
data=json.load(sys.stdin)
tools = data.get('data', [])
print(f'  Total: {len(tools)} tools')
groups = {}
for t in tools:
    g = t.get('toolgroup_id', 'builtin')
    if g not in groups:
        groups[g] = []
    groups[g].append(t['name'])
for g, tlist in groups.items():
    print(f'  {g}: {len(tlist)} tools')
" 2>/dev/null || echo "  Could not fetch tools"
    echo ""
}

# Add MCP server to existing namespace
add_mcp() {
    local mcp_name="$1"
    
    echo ""
    echo "=============================================="
    echo -e "${BLUE}  Add MCP Server: $mcp_name${NC}"
    echo "  Namespace: $EXISTING_NS"
    echo "=============================================="
    echo ""
    
    case "$mcp_name" in
        weather)
            echo_info "Adding Weather MCP Server..."
            CONFIG_FILE="$MANIFEST_DIR/llamastack/llama-stack-config-phase1.yaml"
            ;;
        hr)
            echo_info "Adding HR MCP Server (Weather + HR)..."
            CONFIG_FILE="$MANIFEST_DIR/llamastack/llama-stack-config-phase2.yaml"
            ;;
        all|full)
            echo_info "Adding ALL MCP Servers (Weather + HR + Jira + GitHub)..."
            CONFIG_FILE="$MANIFEST_DIR/llamastack/llama-stack-config-full.yaml"
            ;;
        *)
            echo_error "Unknown MCP server: $mcp_name"
            echo "Available options: weather, hr, all"
            exit 1
            ;;
    esac
    
    echo_info "Applying config from: $CONFIG_FILE"
    oc create configmap llama-stack-config \
        --from-file=run.yaml="$CONFIG_FILE" \
        -n $EXISTING_NS \
        --dry-run=client -o yaml | oc apply -f -
    
    echo_info "Restarting LlamaStack..."
    oc delete pod -l app=lsd-genai-playground -n $EXISTING_NS 2>/dev/null || true
    
    echo_info "Waiting for LlamaStack to restart..."
    sleep 5
    oc wait --for=condition=ready pod -l app=lsd-genai-playground -n $EXISTING_NS --timeout=120s 2>/dev/null || true
    
    echo ""
    echo_success "MCP configuration updated!"
    show_mcp_config
}

# Remove all MCP servers (keep only Weather)
reset_mcp() {
    echo ""
    echo "=============================================="
    echo -e "${YELLOW}  Reset to Phase 1 (Weather only)${NC}"
    echo "  Namespace: $EXISTING_NS"
    echo "=============================================="
    echo ""
    
    echo_info "Resetting to Weather MCP only..."
    oc create configmap llama-stack-config \
        --from-file=run.yaml="$MANIFEST_DIR/llamastack/llama-stack-config-phase1.yaml" \
        -n $EXISTING_NS \
        --dry-run=client -o yaml | oc apply -f -
    
    echo_info "Restarting LlamaStack..."
    oc delete pod -l app=lsd-genai-playground -n $EXISTING_NS 2>/dev/null || true
    
    echo_info "Waiting for LlamaStack to restart..."
    sleep 5
    oc wait --for=condition=ready pod -l app=lsd-genai-playground -n $EXISTING_NS --timeout=120s 2>/dev/null || true
    
    echo ""
    echo_success "Reset to Phase 1 complete!"
    show_mcp_config
}

# List available tools
list_tools() {
    echo ""
    echo "=============================================="
    echo -e "${BLUE}  Available Tools${NC}"
    echo "  Namespace: $EXISTING_NS"
    echo "=============================================="
    echo ""
    
    oc exec deployment/lsd-genai-playground -n $EXISTING_NS -- curl -s http://localhost:8321/v1/tools 2>/dev/null | python3 -c "
import sys,json
data=json.load(sys.stdin)
tools = data.get('data', [])
print(f'Total tools: {len(tools)}')
print('')
groups = {}
for t in tools:
    g = t.get('toolgroup_id', 'builtin')
    if g not in groups:
        groups[g] = []
    groups[g].append(t['name'])

for g, tlist in sorted(groups.items()):
    print(f'{g}:')
    for tool in tlist:
        print(f'  - {tool}')
    print('')
" 2>/dev/null || echo_error "Could not fetch tools. Is LlamaStack running?"
}

# Deploy MongoDB Weather MCP Server
deploy_weather_mongodb() {
    echo ""
    echo "=============================================="
    echo -e "${BLUE}  Deploy MongoDB Weather MCP Server${NC}"
    echo "  Namespace: $EXISTING_NS"
    echo "=============================================="
    echo ""
    
    echo_info "Deploying MongoDB + Weather MCP Server..."
    oc apply -f "$MANIFEST_DIR/mcp-servers/weather-mongodb/deploy-weather-mongodb.yaml" -n $EXISTING_NS
    
    echo_info "Waiting for MongoDB to be ready..."
    oc wait --for=condition=ready pod -l app=mongodb -n $EXISTING_NS --timeout=120s 2>/dev/null || true
    
    echo_info "Waiting for data initialization job..."
    sleep 10
    
    echo_info "Waiting for Weather MCP Server to be ready..."
    oc wait --for=condition=ready pod -l app=weather-mongodb-mcp -n $EXISTING_NS --timeout=180s 2>/dev/null || true
    
    ROUTE=$(oc get route weather-mongodb-mcp -n $EXISTING_NS -o jsonpath='{.spec.host}' 2>/dev/null || echo "pending")
    
    echo ""
    echo_success "MongoDB Weather MCP Server deployed!"
    echo_info "Route: https://$ROUTE"
    echo_info "Internal: http://weather-mongodb-mcp.$EXISTING_NS.svc.cluster.local:8000/mcp"
    echo ""
    echo_info "Tools available:"
    echo "  - search_weather (search with filters)"
    echo "  - get_current_weather (latest for station)"
    echo "  - list_stations (all stations)"
    echo "  - get_statistics (database stats)"
    echo "  - health_check (server health)"
    echo ""
    echo_info "To add to LlamaStack, add this toolgroup:"
    echo ""
    echo "  - toolgroup_id: mcp::weather-mongodb"
    echo "    provider_id: model-context-protocol"
    echo "    mcp_endpoint:"
    echo "      uri: http://weather-mongodb-mcp.$EXISTING_NS.svc.cluster.local:8000/mcp"
}

# Main
check_login

case "${1:-help}" in
    # Multi-namespace deployment commands
    phase1)
        deploy_phase1
        ;;
    phase2)
        deploy_phase2
        ;;
    full)
        deploy_full
        ;;
    all)
        deploy_phase1
        deploy_phase2
        deploy_full
        ;;
    status)
        show_status
        ;;
    cleanup)
        cleanup
        ;;
    
    # Single namespace MCP management commands
    config)
        show_mcp_config
        ;;
    add)
        add_mcp "$2"
        ;;
    reset)
        reset_mcp
        ;;
    tools)
        list_tools
        ;;
    deploy-weather-mongodb)
        deploy_weather_mongodb
        ;;
    
    *)
        echo ""
        echo "LlamaStack MCP Demo Deployment Script"
        echo ""
        echo "Usage: $0 [command]"
        echo ""
        echo "═══════════════════════════════════════════════════════════"
        echo "  MULTI-NAMESPACE DEPLOYMENT (separate LlamaStack instances)"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
        echo "Commands:"
        echo "  phase1    Deploy Phase 1 namespace (Weather MCP only)"
        echo "  phase2    Deploy Phase 2 namespace (Weather + HR MCPs)"
        echo "  full      Deploy Full namespace (All 4 MCP servers)"
        echo "  all       Deploy all phase namespaces"
        echo "  status    Show deployment status of all namespaces"
        echo "  cleanup   Remove all demo namespaces"
        echo ""
        echo "═══════════════════════════════════════════════════════════"
        echo "  SINGLE NAMESPACE MCP MANAGEMENT (modify existing LlamaStack)"
        echo "  Default namespace: my-first-model (set NAMESPACE to change)"
        echo "═══════════════════════════════════════════════════════════"
        echo ""
        echo "Commands:"
        echo "  config                  Show current MCP configuration"
        echo "  add [weather|hr|all]    Add MCP servers to LlamaStack"
        echo "  reset                   Reset to Phase 1 (Weather only)"
        echo "  tools                   List all available tools"
        echo "  deploy-weather-mongodb  Deploy MongoDB-based Weather MCP"
        echo ""
        echo "Environment Variables:"
        echo "  NAMESPACE       Target namespace (default: my-first-model)"
        echo "  GITHUB_TOKEN    GitHub Personal Access Token for GitHub MCP"
        echo ""
        echo "Examples:"
        echo "  $0 config                        # Show current MCP config"
        echo "  $0 add hr                        # Add HR MCP (Weather + HR)"
        echo "  $0 add all                       # Add all 4 MCP servers"
        echo "  $0 reset                         # Reset to Weather only"
        echo "  $0 tools                         # List available tools"
        echo "  NAMESPACE=my-ns $0 add hr        # Add HR to custom namespace"
        echo ""
        ;;
esac
