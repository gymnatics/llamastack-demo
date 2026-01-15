#!/bin/bash
#
# Admin Workshop Setup Script
# ============================
# This script helps the admin set up and test the workshop flow.
# It deploys MCP servers and tests each step - but does NOT deploy the model.
#
# The admin should deploy the model manually via the UI (like users will do).
#
# Usage:
#   ./scripts/admin-workshop-setup.sh <namespace>
#
# Example:
#   ./scripts/admin-workshop-setup.sh admin-workshop
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if namespace is provided
if [ -z "$1" ]; then
    echo -e "${RED}Error: Please provide a namespace${NC}"
    echo "Usage: $0 <namespace>"
    echo "Example: $0 admin-workshop"
    exit 1
fi

NAMESPACE=$1
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         Admin Workshop Setup Script                        ║${NC}"
echo -e "${BLUE}║         Namespace: ${YELLOW}$NAMESPACE${BLUE}                              ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to wait for deployment
wait_for_deployment() {
    local deployment=$1
    local timeout=${2:-180}
    echo -e "${YELLOW}⏳ Waiting for deployment/$deployment to be ready...${NC}"
    if oc wait --for=condition=available deployment/$deployment -n $NAMESPACE --timeout=${timeout}s 2>/dev/null; then
        echo -e "${GREEN}✓ deployment/$deployment is ready${NC}"
        return 0
    else
        echo -e "${RED}✗ deployment/$deployment failed to become ready${NC}"
        return 1
    fi
}

# Function to wait for job
wait_for_job() {
    local job=$1
    local timeout=${2:-120}
    echo -e "${YELLOW}⏳ Waiting for job/$job to complete...${NC}"
    if oc wait --for=condition=complete job/$job -n $NAMESPACE --timeout=${timeout}s 2>/dev/null; then
        echo -e "${GREEN}✓ job/$job completed${NC}"
        return 0
    else
        echo -e "${RED}✗ job/$job failed to complete${NC}"
        return 1
    fi
}

# Function to test MCP server
test_mcp_server() {
    local service=$1
    local port=$2
    local name=$3
    echo -e "${YELLOW}🧪 Testing $name MCP server...${NC}"
    
    # Create a test pod to curl the MCP server
    local result=$(oc run test-mcp-$RANDOM --rm -i --restart=Never \
        --image=curlimages/curl:latest \
        -n $NAMESPACE \
        -- curl -s -o /dev/null -w "%{http_code}" \
        http://$service:$port/mcp 2>/dev/null || echo "000")
    
    if [ "$result" == "200" ] || [ "$result" == "405" ]; then
        echo -e "${GREEN}✓ $name MCP server is responding (HTTP $result)${NC}"
        return 0
    else
        echo -e "${RED}✗ $name MCP server not responding (HTTP $result)${NC}"
        return 1
    fi
}

# ============================================================
# STEP 0: Check Prerequisites
# ============================================================
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}STEP 0: Checking Prerequisites${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check if logged in
if ! oc whoami &>/dev/null; then
    echo -e "${RED}✗ Not logged into OpenShift. Please run 'oc login' first.${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Logged in as: $(oc whoami)${NC}"

# Check if namespace exists, create if not
if oc get namespace $NAMESPACE &>/dev/null; then
    echo -e "${GREEN}✓ Namespace $NAMESPACE exists${NC}"
else
    echo -e "${YELLOW}Creating namespace $NAMESPACE...${NC}"
    oc new-project $NAMESPACE || oc create namespace $NAMESPACE
    echo -e "${GREEN}✓ Namespace $NAMESPACE created${NC}"
fi

# Switch to namespace
oc project $NAMESPACE

# ============================================================
# STEP 1: Deploy Weather MCP Server
# ============================================================
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}STEP 1: Deploy Weather MCP Server (Part 2 - Phase 1)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${YELLOW}📦 Deploying Weather MCP (MongoDB + MCP Server)...${NC}"
oc apply -f "$REPO_ROOT/manifests/mcp-servers/weather-mongodb/deploy-weather-mongodb.yaml" -n $NAMESPACE

# Wait for MongoDB
wait_for_deployment "mongodb" 120

# Wait for init job
wait_for_job "init-weather-data" 120

# Wait for Weather MCP
wait_for_deployment "weather-mongodb-mcp" 180

echo -e "${GREEN}✓ Weather MCP deployed successfully${NC}"

# ============================================================
# STEP 2: Deploy HR MCP Server
# ============================================================
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}STEP 2: Deploy HR MCP Server (Part 2 - for Phase 2)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${YELLOW}📦 Deploying HR MCP Server...${NC}"
oc apply -f "$REPO_ROOT/manifests/workshop/deploy-hr-mcp-simple.yaml" -n $NAMESPACE

# Wait for HR MCP
wait_for_deployment "hr-mcp-server" 180

echo -e "${GREEN}✓ HR MCP deployed successfully${NC}"

# ============================================================
# STEP 3: Test MCP Servers
# ============================================================
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}STEP 3: Test MCP Servers${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Give servers a moment to fully initialize
sleep 5

test_mcp_server "weather-mongodb-mcp" "8000" "Weather"
test_mcp_server "hr-mcp-server" "8000" "HR"

# ============================================================
# STEP 4: Manual Steps Required
# ============================================================
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}STEP 4: Manual Steps Required${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${YELLOW}
┌─────────────────────────────────────────────────────────────────┐
│  🔧 MANUAL STEPS REQUIRED                                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  1. DEPLOY MODEL (via OpenShift AI Dashboard):                  │
│     • Go to Data Science Projects → $NAMESPACE
│     • Create model connection:                                  │
│       - URI: oci://quay.io/redhat-ai-services/modelcar-catalog:llama-3.2-3b-instruct
│     • Deploy model with vLLM runtime + GPU profile              │
│     • Wait for model to be Running (~3-5 min)                   │
│                                                                 │
│  2. ENABLE PLAYGROUND:                                          │
│     • Go to AI Asset Endpoints                                  │
│     • Click 'Add to Playground' on your model                   │
│     • Wait for LlamaStack Distribution (~2 min)                 │
│                                                                 │
│  3. REGISTER MCP ENDPOINTS:                                     │
│     • Go to AI Asset Endpoints → Add endpoint → MCP Server      │
│     • Weather: http://weather-mongodb-mcp:8000/mcp              │
│     • HR: http://hr-mcp-server:8000/mcp                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
${NC}"

echo -e "${YELLOW}Press Enter when you have completed the manual steps...${NC}"
read -r

# ============================================================
# STEP 5: Verify LlamaStack is Running
# ============================================================
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}STEP 5: Verify LlamaStack is Running${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

# Check if LlamaStack pod exists
if oc get deployment lsd-genai-playground -n $NAMESPACE &>/dev/null; then
    echo -e "${GREEN}✓ LlamaStack deployment found${NC}"
    
    # Check models
    echo -e "${YELLOW}🔍 Checking available models...${NC}"
    oc exec deployment/lsd-genai-playground -n $NAMESPACE -- \
        curl -s http://localhost:8321/v1/models 2>/dev/null | python3 -c "
import json,sys
try:
    data=json.load(sys.stdin)
    llms=[m for m in data.get('data',[]) if m.get('model_type')=='llm']
    print(f'LLM Models: {len(llms)}')
    for m in llms:
        print(f\"  - {m.get('identifier')} ({m.get('provider_id')})\")
except:
    print('Could not parse models response')
" || echo -e "${RED}Could not connect to LlamaStack${NC}"

    # Check tools
    echo -e "${YELLOW}🔍 Checking available tools...${NC}"
    oc exec deployment/lsd-genai-playground -n $NAMESPACE -- \
        curl -s http://localhost:8321/v1/tools 2>/dev/null | python3 -c "
import json,sys
try:
    data=json.load(sys.stdin)
    tools=data if isinstance(data,list) else data.get('data',[])
    mcps=set(t.get('toolgroup_id','') for t in tools if t.get('toolgroup_id','').startswith('mcp::'))
    print(f'MCP Servers in toolgroup: {len(mcps)}')
    for mcp in sorted(mcps):
        print(f'  - {mcp}')
except:
    print('Could not parse tools response')
" || echo -e "${RED}Could not connect to LlamaStack${NC}"

else
    echo -e "${RED}✗ LlamaStack deployment not found. Did you enable the Playground?${NC}"
fi

# ============================================================
# STEP 6: Test Phase 1 (Weather Only)
# ============================================================
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}STEP 6: Test Phase 1 - Weather MCP Only${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${YELLOW}
At this point, users would:
1. Test the Playground with Weather queries
2. Run the notebook for the first time (sees ~3 tools)

Test in Playground:
  'What is the weather in New York City?'
  'List all available weather stations'
${NC}"

echo -e "${YELLOW}Press Enter to continue to Phase 2 setup...${NC}"
read -r

# ============================================================
# STEP 7: Apply Phase 2 Config (Add HR to toolgroup)
# ============================================================
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}STEP 7: Apply Phase 2 Config (Add HR MCP to toolgroup)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${YELLOW}📝 Applying Phase 2 LlamaStack config...${NC}"
oc apply -f "$REPO_ROOT/manifests/workshop/llama-stack-config-workshop-phase2.yaml" -n $NAMESPACE

echo -e "${YELLOW}🔄 Restarting LlamaStack to pick up new config...${NC}"
oc delete pod -l app=lsd-genai-playground -n $NAMESPACE

echo -e "${YELLOW}⏳ Waiting for LlamaStack to restart...${NC}"
sleep 10
wait_for_deployment "lsd-genai-playground" 120

# Verify new tools
echo -e "${YELLOW}🔍 Verifying Phase 2 tools...${NC}"
sleep 5
oc exec deployment/lsd-genai-playground -n $NAMESPACE -- \
    curl -s http://localhost:8321/v1/tools 2>/dev/null | python3 -c "
import json,sys
try:
    data=json.load(sys.stdin)
    tools=data if isinstance(data,list) else data.get('data',[])
    groups={}
    for t in tools:
        tg=t.get('toolgroup_id','')
        if tg not in groups: groups[tg]=0
        groups[tg]+=1
    print(f'Total tools: {len(tools)}')
    for tg,count in sorted(groups.items()):
        print(f'  - {tg}: {count} tools')
except:
    print('Could not parse tools response')
" || echo -e "${RED}Could not connect to LlamaStack${NC}"

# ============================================================
# STEP 8: Test Phase 2 (Weather + HR)
# ============================================================
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}STEP 8: Test Phase 2 - Weather + HR MCPs${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${YELLOW}
At this point, users would:
1. Test the Playground with HR queries
2. Run the notebook for the second time (sees ~8 tools)

Test in Playground:
  'List all employees in the company'
  'What is the vacation balance for employee EMP001?'
  'What job openings are available?'
${NC}"

# ============================================================
# SUMMARY
# ============================================================
echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}✅ SETUP COMPLETE${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

echo -e "${GREEN}
┌─────────────────────────────────────────────────────────────────┐
│  Workshop Admin Setup Complete!                                 │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Namespace: $NAMESPACE
│                                                                 │
│  Deployed:                                                      │
│    ✓ Weather MCP Server (weather-mongodb-mcp)                   │
│    ✓ HR MCP Server (hr-mcp-server)                              │
│    ✓ Phase 2 LlamaStack Config                                  │
│                                                                 │
│  Next Steps:                                                    │
│    1. Test the Playground with various queries                  │
│    2. Open workbench and test notebooks:                        │
│       - notebooks/workshop_client_demo.ipynb (user notebook)    │
│       - notebooks/admin/azure_openai_demo.ipynb (admin demo)    │
│    3. For Azure demo, create the secret:                        │
│       oc create secret generic azure-openai-secret \\            │
│         --from-literal=endpoint=\"https://...\" \\                │
│         --from-literal=api-key=\"...\" \\                         │
│         -n $NAMESPACE
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
${NC}"

echo -e "${YELLOW}To reset and start over:${NC}"
echo -e "  oc delete project $NAMESPACE"
echo ""
