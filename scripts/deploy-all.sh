#!/bin/bash

################################################################################
# LlamaStack MCP Demo - Full Deployment Script
################################################################################
# This script deploys all components for the LlamaStack MCP Demo:
# - HR API Backend
# - HR MCP Server
# - Jira/Confluence MCP Server
# - Updates MCP Servers ConfigMap (AI Assets)
# - Updates LlamaStack config with toolgroups
# - Deploys enhanced frontend
################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
NAMESPACE="${NAMESPACE:-my-first-model}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST_DIR="$(dirname "$SCRIPT_DIR")/manifests"

print_header() {
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${MAGENTA} $1${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_step() { echo -e "${CYAN}▶ $1${NC}"; }
print_success() { echo -e "${GREEN}✓ $1${NC}"; }
print_error() { echo -e "${RED}✗ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ $1${NC}"; }

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check if logged in
    if ! oc whoami &>/dev/null; then
        print_error "Not logged in to OpenShift cluster"
        echo "Please run: oc login <cluster-url>"
        exit 1
    fi
    print_success "Logged in as: $(oc whoami)"
    print_success "Cluster: $(oc whoami --show-server)"
    
    # Check namespace exists
    if ! oc get namespace "$NAMESPACE" &>/dev/null; then
        print_error "Namespace $NAMESPACE does not exist"
        exit 1
    fi
    print_success "Namespace $NAMESPACE exists"
    
    # Check LlamaStack is running
    if ! oc get deployment -n "$NAMESPACE" -l llamastack.io/distribution &>/dev/null; then
        print_warning "LlamaStack distribution not found in $NAMESPACE"
    else
        print_success "LlamaStack distribution found"
    fi
    
    # Check Weather MCP is running
    if oc get deployment mcp-weather -n "$NAMESPACE" &>/dev/null; then
        print_success "Weather MCP server found (colleague's version on port 3001)"
    else
        print_warning "Weather MCP server not found"
    fi
}

deploy_hr_api() {
    print_header "Deploying HR API Backend"
    
    print_step "Applying HR API manifests..."
    oc apply -f "$MANIFEST_DIR/mcp-servers/hr-api.yaml" -n "$NAMESPACE"
    
    print_step "Waiting for HR API to be ready..."
    if oc wait --for=condition=available deployment/hr-api -n "$NAMESPACE" --timeout=120s; then
        print_success "HR API is ready"
    else
        print_warning "HR API may still be starting"
    fi
    
    # Test HR API
    print_step "Testing HR API health..."
    HR_API_POD=$(oc get pod -n "$NAMESPACE" -l app=hr-api -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$HR_API_POD" ]; then
        if oc exec -n "$NAMESPACE" "$HR_API_POD" -- curl -s http://localhost:8080/health 2>/dev/null | grep -q "healthy"; then
            print_success "HR API health check passed"
        else
            print_warning "HR API health check inconclusive"
        fi
    fi
}

deploy_hr_mcp_server() {
    print_header "Deploying HR MCP Server"
    
    # Apply ConfigMaps first
    print_step "Applying HR MCP Server ConfigMaps..."
    oc apply -f "$MANIFEST_DIR/mcp-servers/hr-mcp-server.yaml" -n "$NAMESPACE"
    
    # Check if ImageStream exists
    if ! oc get imagestream hr-mcp-server -n "$NAMESPACE" &>/dev/null; then
        print_step "Creating ImageStream..."
    fi
    
    # Create build directory
    BUILD_DIR=$(mktemp -d)
    print_step "Preparing build context in $BUILD_DIR..."
    
    # Extract code from ConfigMap
    oc get configmap hr-mcp-server-code -n "$NAMESPACE" -o jsonpath='{.data.server\.py}' > "$BUILD_DIR/server.py"
    oc get configmap hr-mcp-server-code -n "$NAMESPACE" -o jsonpath='{.data.requirements\.txt}' > "$BUILD_DIR/requirements.txt"
    oc get configmap hr-mcp-dockerfile -n "$NAMESPACE" -o jsonpath='{.data.Dockerfile}' > "$BUILD_DIR/Dockerfile"
    
    # Start build
    print_step "Starting HR MCP Server build..."
    oc start-build hr-mcp-server -n "$NAMESPACE" --from-dir="$BUILD_DIR" --follow || {
        print_warning "Build may have failed, checking status..."
    }
    
    # Cleanup
    rm -rf "$BUILD_DIR"
    
    # Wait for deployment
    print_step "Waiting for HR MCP Server deployment..."
    sleep 10
    if oc wait --for=condition=available deployment/hr-mcp-server -n "$NAMESPACE" --timeout=180s 2>/dev/null; then
        print_success "HR MCP Server is ready"
    else
        print_warning "HR MCP Server may still be starting"
        print_info "Check with: oc logs -f deployment/hr-mcp-server -n $NAMESPACE"
    fi
}

deploy_jira_mcp_server() {
    print_header "Deploying Jira/Confluence MCP Server"
    
    # Apply ConfigMaps first
    print_step "Applying Jira MCP Server ConfigMaps..."
    oc apply -f "$MANIFEST_DIR/mcp-servers/jira-mcp-server.yaml" -n "$NAMESPACE"
    
    # Create build directory
    BUILD_DIR=$(mktemp -d)
    print_step "Preparing build context in $BUILD_DIR..."
    
    # Extract code from ConfigMap
    oc get configmap jira-mcp-server-code -n "$NAMESPACE" -o jsonpath='{.data.server\.py}' > "$BUILD_DIR/server.py"
    oc get configmap jira-mcp-server-code -n "$NAMESPACE" -o jsonpath='{.data.requirements\.txt}' > "$BUILD_DIR/requirements.txt"
    oc get configmap jira-mcp-dockerfile -n "$NAMESPACE" -o jsonpath='{.data.Dockerfile}' > "$BUILD_DIR/Dockerfile"
    
    # Start build
    print_step "Starting Jira MCP Server build..."
    oc start-build jira-mcp-server -n "$NAMESPACE" --from-dir="$BUILD_DIR" --follow || {
        print_warning "Build may have failed, checking status..."
    }
    
    # Cleanup
    rm -rf "$BUILD_DIR"
    
    # Wait for deployment
    print_step "Waiting for Jira MCP Server deployment..."
    sleep 10
    if oc wait --for=condition=available deployment/jira-mcp-server -n "$NAMESPACE" --timeout=180s 2>/dev/null; then
        print_success "Jira MCP Server is ready"
    else
        print_warning "Jira MCP Server may still be starting"
        print_info "Check with: oc logs -f deployment/jira-mcp-server -n $NAMESPACE"
    fi
}

update_mcp_configmap() {
    print_header "Updating MCP Servers ConfigMap (AI Assets)"
    
    print_step "Applying MCP Servers ConfigMap..."
    oc apply -f "$MANIFEST_DIR/mcp-servers/mcp-servers-configmap.yaml"
    
    print_success "MCP Servers ConfigMap updated in redhat-ods-applications"
    
    print_info "Registered MCP Servers:"
    echo "  - Weather MCP Server (port 3001)"
    echo "  - GitHub MCP Server (external)"
    echo "  - HR MCP Server (port 8000)"
    echo "  - Jira/Confluence MCP Server (port 8000)"
}

update_llamastack_config() {
    print_header "Updating LlamaStack Configuration"
    
    print_step "Getting current LlamaStack config..."
    CURRENT_CONFIG=$(oc get configmap llama-stack-config -n "$NAMESPACE" -o jsonpath='{.data.run\.yaml}')
    
    # Check if tool_groups already has MCP entries
    if echo "$CURRENT_CONFIG" | grep -q "mcp::weather-data"; then
        print_info "MCP toolgroups already configured"
        read -p "Do you want to update the config anyway? (y/N): " update_choice
        if [[ ! "$update_choice" =~ ^[Yy]$ ]]; then
            print_info "Skipping LlamaStack config update"
            return
        fi
    fi
    
    print_step "Applying updated LlamaStack config..."
    oc apply -f "$MANIFEST_DIR/llamastack/llama-stack-config-patch.yaml" -n "$NAMESPACE"
    
    print_step "Restarting LlamaStack to load new config..."
    oc delete pod -l llamastack.io/distribution=lsd-genai-playground -n "$NAMESPACE" --ignore-not-found=true
    
    print_step "Waiting for LlamaStack to restart..."
    sleep 10
    if oc wait --for=condition=available deployment -l llamastack.io/distribution=lsd-genai-playground -n "$NAMESPACE" --timeout=180s 2>/dev/null; then
        print_success "LlamaStack restarted with new config"
    else
        print_warning "LlamaStack may still be restarting"
    fi
}

verify_deployment() {
    print_header "Verifying Deployment"
    
    echo ""
    print_step "Checking pod status..."
    oc get pods -n "$NAMESPACE" -l 'app in (hr-api,hr-mcp-server,jira-mcp-server,mcp-weather)'
    
    echo ""
    print_step "Checking services..."
    oc get svc -n "$NAMESPACE" -l 'app in (hr-api,hr-mcp-server,jira-mcp-server,mcp-weather)'
    
    echo ""
    print_step "Checking routes..."
    oc get routes -n "$NAMESPACE" 2>/dev/null || print_info "No routes found"
    
    echo ""
    print_step "Checking LlamaStack tools..."
    LLAMASTACK_POD=$(oc get pod -n "$NAMESPACE" -l llamastack.io/distribution=lsd-genai-playground -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$LLAMASTACK_POD" ]; then
        print_info "LlamaStack pod: $LLAMASTACK_POD"
        # Try to get tools count
        TOOLS_COUNT=$(oc exec -n "$NAMESPACE" "$LLAMASTACK_POD" -- curl -s http://localhost:8321/v1/tools 2>/dev/null | grep -o '"name"' | wc -l || echo "0")
        print_info "Available tools: $TOOLS_COUNT"
    fi
}

print_summary() {
    print_header "Deployment Summary"
    
    echo -e "${GREEN}✅ Deployment Complete!${NC}"
    echo ""
    echo "MCP Servers deployed:"
    echo "  🌤️  Weather MCP - http://mcp-weather.$NAMESPACE.svc.cluster.local:3001"
    echo "  👥 HR MCP - http://hr-mcp-server.$NAMESPACE.svc.cluster.local:8000"
    echo "  📋 Jira MCP - http://jira-mcp-server.$NAMESPACE.svc.cluster.local:8000"
    echo "  🐙 GitHub MCP - https://api.githubcopilot.com/mcp (external)"
    echo ""
    echo "Next steps:"
    echo "  1. Access the GenAI Playground in RHOAI Dashboard"
    echo "  2. Verify MCP servers are visible in the Tools section"
    echo "  3. Test with sample queries:"
    echo "     - 'What's the weather in New York?'"
    echo "     - 'Check vacation balance for EMP001'"
    echo "     - 'Search for bugs in the PLAT project'"
    echo ""
    echo "Troubleshooting:"
    echo "  oc logs -f deployment/hr-mcp-server -n $NAMESPACE"
    echo "  oc logs -f deployment/jira-mcp-server -n $NAMESPACE"
    echo "  oc get configmap llama-stack-config -n $NAMESPACE -o yaml"
}

# Main execution
main() {
    print_header "LlamaStack MCP Demo - Full Deployment"
    
    echo "This script will deploy:"
    echo "  - HR API Backend"
    echo "  - HR MCP Server"
    echo "  - Jira/Confluence MCP Server"
    echo "  - Update MCP Servers ConfigMap"
    echo "  - Update LlamaStack config"
    echo ""
    echo "Target namespace: $NAMESPACE"
    echo ""
    
    read -p "Continue with deployment? (Y/n): " confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_info "Deployment cancelled"
        exit 0
    fi
    
    check_prerequisites
    deploy_hr_api
    deploy_hr_mcp_server
    deploy_jira_mcp_server
    update_mcp_configmap
    update_llamastack_config
    verify_deployment
    print_summary
}

# Parse arguments
case "${1:-}" in
    --hr-only)
        check_prerequisites
        deploy_hr_api
        deploy_hr_mcp_server
        ;;
    --jira-only)
        check_prerequisites
        deploy_jira_mcp_server
        ;;
    --config-only)
        check_prerequisites
        update_mcp_configmap
        update_llamastack_config
        ;;
    --verify)
        verify_deployment
        ;;
    --help|-h)
        echo "Usage: $0 [option]"
        echo ""
        echo "Options:"
        echo "  (no option)    Full deployment"
        echo "  --hr-only      Deploy only HR API and MCP server"
        echo "  --jira-only    Deploy only Jira MCP server"
        echo "  --config-only  Update ConfigMaps only"
        echo "  --verify       Verify deployment status"
        echo "  --help         Show this help"
        ;;
    *)
        main
        ;;
esac
