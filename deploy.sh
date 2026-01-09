#!/bin/bash
################################################################################
# LlamaStack MCP Demo - Deployment Script
################################################################################
# Deploys the LlamaStack MCP Demo components:
# - MongoDB with sample weather data
# - Weather MCP Server
# - Streamlit Demo UI
#
# Note: For full LlamaStack deployment with provider selection, use the
# rhoai-toolkit.sh from https://github.com/gymnatics/openshift-installation
################################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║ $1${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_step() { echo -e "${CYAN}▶ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

print_header "LlamaStack MCP Demo Deployment"

# Check if oc is installed
if ! command -v oc &>/dev/null; then
    print_error "oc CLI not found. Please install OpenShift CLI."
    exit 1
fi

# Check if logged in
if ! oc whoami &>/dev/null; then
    print_error "Not logged in to OpenShift cluster"
    echo ""
    echo "Please log in first:"
    echo "  oc login --token=<your-token> --server=<cluster-url>"
    exit 1
fi

print_success "Connected to cluster: $(oc whoami --show-server)"

# Get current namespace
CURRENT_NS=$(oc project -q 2>/dev/null)
echo ""
echo -e "${CYAN}Current namespace: ${YELLOW}$CURRENT_NS${NC}"
echo ""
read -p "Deploy to this namespace? (Y/n): " confirm
if [[ "$confirm" =~ ^[Nn]$ ]]; then
    read -p "Enter target namespace: " TARGET_NS
    if ! oc get namespace "$TARGET_NS" &>/dev/null; then
        print_warning "Namespace '$TARGET_NS' does not exist"
        read -p "Create it? (y/N): " create_ns
        if [[ "$create_ns" =~ ^[Yy]$ ]]; then
            oc new-project "$TARGET_NS" 2>/dev/null || oc create namespace "$TARGET_NS"
        else
            exit 1
        fi
    fi
    oc project "$TARGET_NS"
else
    TARGET_NS="$CURRENT_NS"
fi

echo ""
echo -e "${CYAN}What would you like to deploy?${NC}"
echo ""
echo "1) Complete Demo Stack (MongoDB + Weather MCP + Demo UI)"
echo "   → Connects to your existing LlamaStack"
echo ""
echo "2) Weather MCP Server + MongoDB only"
echo "   → Just the MCP server and database"
echo ""
echo "3) Demo UI only"
echo "   → Connect to existing LlamaStack and MCP services"
echo ""
echo -e "${YELLOW}Note: For full LlamaStack deployment with provider selection,${NC}"
echo -e "${YELLOW}      use rhoai-toolkit.sh from the openshift-installation repo.${NC}"
echo ""
read -p "Enter your choice [1]: " deploy_choice
deploy_choice="${deploy_choice:-1}"

# Helper function to apply manifests with namespace substitution
apply_manifest() {
    local file="$1"
    sed -e "s/namespace: demo-test/namespace: $TARGET_NS/g" \
        -e "s/NAMESPACE_PLACEHOLDER/$TARGET_NS/g" \
        -e "s|demo-test/|$TARGET_NS/|g" \
        "$file" | oc apply -f -
}

# Deploy MongoDB + Weather MCP Server
deploy_mcp_mongodb() {
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA} Deploying MongoDB + Weather MCP Server${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    
    # MongoDB
    print_step "Deploying MongoDB..."
    if oc get pvc mongodb-data -n "$TARGET_NS" &>/dev/null; then
        print_info "MongoDB PVC already exists, skipping PVC creation"
        apply_manifest "$SCRIPT_DIR/mcp/mongodb-deployment.yaml" 2>/dev/null || true
    else
        apply_manifest "$SCRIPT_DIR/mcp/mongodb-deployment.yaml"
    fi
    
    print_step "Waiting for MongoDB to be ready..."
    if oc wait --for=condition=available deployment/mongodb -n "$TARGET_NS" --timeout=180s 2>/dev/null; then
        print_success "MongoDB is ready"
    else
        print_warning "MongoDB may still be starting"
    fi
    
    # Initialize data
    print_step "Initializing sample weather data..."
    oc delete job init-weather-data -n "$TARGET_NS" 2>/dev/null || true
    apply_manifest "$SCRIPT_DIR/mcp/init-data-job.yaml"
    
    print_step "Waiting for data initialization..."
    if oc wait --for=condition=complete job/init-weather-data -n "$TARGET_NS" --timeout=120s 2>/dev/null; then
        print_success "Sample data loaded (14 stations, 48 hours each)"
    else
        print_warning "Data initialization may still be running"
    fi
    
    # Build MCP Server
    print_step "Building Weather MCP Server..."
    apply_manifest "$SCRIPT_DIR/mcp/buildconfig.yaml"
    
    if oc start-build weather-mcp-server --from-dir="$SCRIPT_DIR/mcp" --follow -n "$TARGET_NS"; then
        print_success "Build completed"
    else
        print_error "Build failed"
        return 1
    fi
    
    # Deploy MCP Server
    print_step "Deploying Weather MCP Server..."
    apply_manifest "$SCRIPT_DIR/mcp/deployment.yaml"
    
    if oc rollout status deployment/weather-mcp-server -n "$TARGET_NS" --timeout=120s 2>/dev/null; then
        print_success "Weather MCP Server deployed"
    else
        print_warning "MCP Server may still be starting"
    fi
}

# Deploy Demo UI
deploy_demo_ui() {
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA} Deploying LlamaStack Demo UI${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    
    # Get LlamaStack URL
    local detected_llamastack=""
    detected_llamastack=$(oc get svc -n "$TARGET_NS" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | tr ' ' '\n' | grep -E "llamastack-demo|llama|lsd" | head -1)
    
    if [ -n "$detected_llamastack" ]; then
        local default_llamastack_url="http://${detected_llamastack}.${TARGET_NS}.svc.cluster.local:8321"
        print_info "Detected LlamaStack service: $detected_llamastack"
    else
        local default_llamastack_url="http://lsd-genai-playground-service.${TARGET_NS}.svc.cluster.local:8321"
    fi
    
    echo ""
    read -p "LlamaStack URL [$default_llamastack_url]: " LLAMASTACK_URL
    LLAMASTACK_URL="${LLAMASTACK_URL:-$default_llamastack_url}"
    
    read -p "Model ID [qwen3-8b]: " MODEL_ID
    MODEL_ID="${MODEL_ID:-qwen3-8b}"
    
    # MCP Server URL
    local mcp_url="http://weather-mcp-server.${TARGET_NS}.svc.cluster.local:8000"
    if oc get svc weather-mcp-server -n "$TARGET_NS" &>/dev/null; then
        print_info "Using deployed Weather MCP Server"
    else
        read -p "MCP Server URL [$mcp_url]: " mcp_url_input
        mcp_url="${mcp_url_input:-$mcp_url}"
    fi
    
    # Apply ConfigMap with values
    print_step "Applying ConfigMap..."
    sed -e "s/namespace: demo-test/namespace: $TARGET_NS/g" \
        -e "s|demo-test/|$TARGET_NS/|g" \
        -e "s|LLAMASTACK_URL:.*|LLAMASTACK_URL: \"$LLAMASTACK_URL\"|g" \
        -e "s|MODEL_ID:.*|MODEL_ID: \"$MODEL_ID\"|g" \
        -e "s|MCP_SERVER_URL:.*|MCP_SERVER_URL: \"$mcp_url\"|g" \
        "$SCRIPT_DIR/deployment.yaml" | oc apply -f -
    
    # Build
    print_step "Building Demo UI..."
    apply_manifest "$SCRIPT_DIR/buildconfig.yaml"
    
    if oc start-build llamastack-mcp-demo --from-dir="$SCRIPT_DIR" --follow -n "$TARGET_NS"; then
        print_success "Build completed"
    else
        print_error "Build failed"
        return 1
    fi
    
    # Wait for deployment
    print_step "Waiting for deployment..."
    if oc rollout status deployment/llamastack-mcp-demo -n "$TARGET_NS" --timeout=120s 2>/dev/null; then
        print_success "Demo UI deployed"
    else
        print_warning "Deployment may still be starting"
    fi
}

# Main deployment logic
case $deploy_choice in
    1)
        deploy_mcp_mongodb
        deploy_demo_ui
        ;;
    2)
        deploy_mcp_mongodb
        ;;
    3)
        deploy_demo_ui
        ;;
    *)
        print_error "Invalid choice"
        exit 1
        ;;
esac

# Print summary
echo ""
print_header "Deployment Complete!"

if [[ "$deploy_choice" == "1" ]] || [[ "$deploy_choice" == "2" ]]; then
    echo -e "${CYAN}📦 Deployed Components:${NC}"
    echo "   • MongoDB: mongodb.$TARGET_NS.svc.cluster.local:27017"
    echo "   • Weather MCP Server: weather-mcp-server.$TARGET_NS.svc.cluster.local:8000"
    echo ""
    echo -e "${YELLOW}⚠️  Register MCP with LlamaStack:${NC}"
    echo "   Add to your LlamaStack config under tool_groups:"
    echo ""
    echo "   - toolgroup_id: mcp::weather-data"
    echo "     provider_id: model-context-protocol"
    echo "     mcp_endpoint:"
    echo "       uri: http://weather-mcp-server.$TARGET_NS.svc.cluster.local:8000/mcp"
    echo ""
fi

if [[ "$deploy_choice" == "1" ]] || [[ "$deploy_choice" == "3" ]]; then
    route_url=$(oc get route llamastack-mcp-demo -n "$TARGET_NS" -o jsonpath='{.spec.host}' 2>/dev/null)
    if [ -n "$route_url" ]; then
        echo -e "${CYAN}🌐 Demo UI URL:${NC}"
        echo -e "   ${GREEN}https://$route_url${NC}"
        echo ""
    fi
fi

echo -e "${GREEN}✅ Done!${NC}"
