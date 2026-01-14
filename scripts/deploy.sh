#!/bin/bash
# LlamaStack MCP Demo - Deployment Script
#
# Auto-detects your current namespace and deploys there.
# No configuration needed - just run it!
#
# Usage:
#   ./deploy.sh              # Deploy Weather MCP (Phase 1)
#   ./deploy.sh phase2       # Deploy Weather + HR MCPs
#   ./deploy.sh full         # Deploy all 4 MCP servers
#   ./deploy.sh status       # Check deployment status
#   ./deploy.sh tools        # List available tools
#   ./deploy.sh add-hr       # Add HR MCP to existing setup
#   ./deploy.sh reset        # Reset to Weather only

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

# Check login
if ! oc whoami &>/dev/null; then
    echo -e "${RED}❌ Not logged in. Run 'oc login' first.${NC}"
    exit 1
fi

# Get current namespace (auto-detect)
NS=$(oc project -q)
SOURCE_NS="my-first-model"

# Header
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}  ${BLUE}🦙 LlamaStack MCP Demo${NC}"
echo -e "${CYAN}║${NC}  Namespace: ${GREEN}$NS${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

case "${1:-help}" in
    phase1)
        echo -e "${BLUE}▶ Deploying Phase 1 (Weather MCP only)...${NC}"
        sed "s/$SOURCE_NS/$NS/g" "$MANIFEST_DIR/phase1/deploy-phase1.yaml" | oc apply -f -
        echo ""
        echo -e "${GREEN}✅ Phase 1 deployed!${NC}"
        echo -e "   MCP Servers: Weather"
        echo -e "   Tools: getforecast"
        ;;
    
    phase2)
        echo -e "${BLUE}▶ Deploying Phase 2 (Weather + HR MCPs)...${NC}"
        sed "s/$SOURCE_NS/$NS/g" "$MANIFEST_DIR/phase2/deploy-phase2.yaml" | oc apply -f -
        echo ""
        echo -e "${GREEN}✅ Phase 2 deployed!${NC}"
        echo -e "   MCP Servers: Weather, HR"
        echo -e "   Tools: getforecast, get_vacation_balance, get_employee_info, ..."
        ;;
    
    full)
        echo -e "${BLUE}▶ Deploying Full (All 4 MCP servers)...${NC}"
        if [ -n "$GITHUB_TOKEN" ]; then
            echo -e "   Creating GitHub token secret..."
            oc create secret generic github-mcp-token \
                --from-literal=GITHUB_PERSONAL_ACCESS_TOKEN="$GITHUB_TOKEN" \
                -n "$NS" --dry-run=client -o yaml | oc apply -f -
        else
            echo -e "${YELLOW}   ⚠ GITHUB_TOKEN not set - GitHub MCP may not work${NC}"
        fi
        sed "s/$SOURCE_NS/$NS/g" "$MANIFEST_DIR/full/deploy-full.yaml" | oc apply -f -
        echo ""
        echo -e "${GREEN}✅ Full deployment complete!${NC}"
        echo -e "   MCP Servers: Weather, HR, Jira, GitHub"
        ;;
    
    status)
        echo -e "${BLUE}📊 Deployment Status${NC}"
        echo ""
        echo -e "${CYAN}Pods:${NC}"
        oc get pods -n "$NS" 2>/dev/null | grep -E "NAME|mcp|llama|weather|hr|jira|github|frontend" || echo "  No demo pods found"
        echo ""
        echo -e "${CYAN}Routes:${NC}"
        oc get routes -n "$NS" 2>/dev/null | grep -E "NAME|llama|mcp|frontend" || echo "  No routes found"
        ;;
    
    tools)
        echo -e "${BLUE}🔧 Available Tools${NC}"
        echo ""
        oc exec deployment/lsd-genai-playground -n "$NS" -- curl -s http://localhost:8321/v1/tools 2>/dev/null | python3 -c "
import sys,json
try:
    data=json.load(sys.stdin)
    tools = data.get('data', [])
    print(f'Total: {len(tools)} tools')
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
except:
    print('Could not fetch tools. Is LlamaStack running?')
" 2>/dev/null || echo -e "${RED}Could not connect to LlamaStack${NC}"
        ;;
    
    config)
        echo -e "${BLUE}📋 Current MCP Configuration${NC}"
        echo ""
        oc get configmap llama-stack-config -n "$NS" -o jsonpath='{.data.run\.yaml}' 2>/dev/null | grep -A4 "toolgroup_id: mcp::" || echo "No MCP toolgroups configured"
        ;;
    
    add)
        MCP_TO_ADD="${2:-}"
        if [ -z "$MCP_TO_ADD" ]; then
            echo -e "${YELLOW}Usage: $0 add <mcp-server>${NC}"
            echo ""
            echo "Available MCP servers:"
            echo "  weather   - Weather forecast (getforecast)"
            echo "  hr        - HR tools (vacation, employees, jobs)"
            echo "  jira      - Jira/Confluence (issues, projects)"
            echo "  github    - GitHub (repos, issues, code search)"
            echo "  all       - All 4 MCP servers"
            echo ""
            echo "Examples:"
            echo "  $0 add hr"
            echo "  $0 add jira"
            echo "  $0 add all"
            exit 0
        fi
        
        case "$MCP_TO_ADD" in
            weather)
                echo -e "${BLUE}▶ Setting LlamaStack to Weather MCP only...${NC}"
                CONFIG_FILE="$MANIFEST_DIR/llamastack/llama-stack-config-phase1.yaml"
                ;;
            hr)
                echo -e "${BLUE}▶ Adding HR MCP to LlamaStack (Weather + HR)...${NC}"
                CONFIG_FILE="$MANIFEST_DIR/llamastack/llama-stack-config-phase2.yaml"
                ;;
            jira|github)
                echo -e "${BLUE}▶ Adding $MCP_TO_ADD MCP to LlamaStack (requires full config)...${NC}"
                CONFIG_FILE="$MANIFEST_DIR/llamastack/llama-stack-config-full.yaml"
                ;;
            all)
                echo -e "${BLUE}▶ Adding all MCPs to LlamaStack...${NC}"
                CONFIG_FILE="$MANIFEST_DIR/llamastack/llama-stack-config-full.yaml"
                ;;
            *)
                echo -e "${RED}Unknown MCP server: $MCP_TO_ADD${NC}"
                echo "Available: weather, hr, jira, github, all"
                exit 1
                ;;
        esac
        
        sed "s/$SOURCE_NS/$NS/g" "$CONFIG_FILE" > /tmp/llama-config.yaml
        oc create configmap llama-stack-config --from-file=run.yaml=/tmp/llama-config.yaml -n "$NS" --dry-run=client -o yaml | oc apply -f -
        oc delete pod -l app=lsd-genai-playground -n "$NS" 2>/dev/null || true
        rm /tmp/llama-config.yaml
        echo -e "${GREEN}✅ MCP configuration updated! LlamaStack restarting...${NC}"
        echo -e "   Wait ~30s then run: $0 tools"
        ;;
    
    reset)
        echo -e "${BLUE}▶ Resetting to Weather MCP only...${NC}"
        sed "s/$SOURCE_NS/$NS/g" "$MANIFEST_DIR/llamastack/llama-stack-config-phase1.yaml" > /tmp/llama-config.yaml
        oc create configmap llama-stack-config --from-file=run.yaml=/tmp/llama-config.yaml -n "$NS" --dry-run=client -o yaml | oc apply -f -
        oc delete pod -l app=lsd-genai-playground -n "$NS" 2>/dev/null || true
        rm /tmp/llama-config.yaml
        echo -e "${GREEN}✅ Reset to Phase 1! LlamaStack restarting...${NC}"
        echo -e "   Wait ~30s then run: $0 tools"
        ;;
    
    help|--help|-h|"")
        echo "Usage: ./deploy.sh [command]"
        echo ""
        echo -e "${CYAN}Deploy Commands:${NC}"
        echo "  phase1    Deploy Weather MCP only"
        echo "  phase2    Deploy Weather + HR MCPs"
        echo "  full      Deploy all 4 MCP servers"
        echo ""
        echo -e "${CYAN}Add MCP Servers:${NC}"
        echo "  add weather   Set to Weather only"
        echo "  add hr        Add HR MCP (Weather + HR)"
        echo "  add jira      Add Jira MCP (all MCPs)"
        echo "  add github    Add GitHub MCP (all MCPs)"
        echo "  add all       Add all 4 MCP servers"
        echo ""
        echo -e "${CYAN}Other Commands:${NC}"
        echo "  reset     Reset to Weather MCP only"
        echo "  status    Show pods and routes"
        echo "  tools     List available tools"
        echo "  config    Show current MCP configuration"
        echo ""
        echo -e "${CYAN}Examples:${NC}"
        echo "  ./deploy.sh phase1      # Start with Weather only"
        echo "  ./deploy.sh add hr      # Add HR MCP"
        echo "  ./deploy.sh add jira    # Add Jira MCP"
        echo "  ./deploy.sh tools       # See available tools"
        echo "  ./deploy.sh reset       # Go back to Weather only"
        echo ""
        ;;
    
    *)
        echo -e "${RED}Unknown command: $1${NC}"
        echo "Run './deploy.sh help' for usage"
        exit 1
        ;;
esac
