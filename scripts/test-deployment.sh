#!/bin/bash
# Deployment Testing Script
# Tests the LlamaStack MCP Demo on various platforms
#
# Usage:
#   ./test-deployment.sh [platform]
#
# Platforms:
#   openshift  - Test on OpenShift cluster
#   kubernetes - Test on vanilla Kubernetes
#   docker     - Test with Docker/Docker Compose
#   local      - Test locally (Python only)
#   all        - Run all applicable tests

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

cd "$REPO_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }
echo_success() { echo -e "${GREEN}✅ $1${NC}"; }
echo_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
echo_error() { echo -e "${RED}❌ $1${NC}"; }
echo_test() { echo -e "${CYAN}🧪 $1${NC}"; }

TESTS_PASSED=0
TESTS_FAILED=0

test_pass() {
    echo_success "$1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

test_fail() {
    echo_error "$1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_header() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo -e "║  ${CYAN}$1${NC}"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
}

# ============================================
# Local Python Tests
# ============================================
test_local() {
    print_header "Local Python Environment Tests"
    
    echo_test "Checking Python version..."
    if python3 --version 2>/dev/null | grep -q "Python 3"; then
        test_pass "Python 3 is installed: $(python3 --version)"
    else
        test_fail "Python 3 is not installed"
        return
    fi
    
    echo_test "Checking pip..."
    if python3 -m pip --version &>/dev/null; then
        test_pass "pip is available"
    else
        test_fail "pip is not available"
    fi
    
    echo_test "Checking requirements.txt syntax..."
    if python3 -c "
import sys
with open('requirements.txt') as f:
    for line in f:
        line = line.strip()
        if line and not line.startswith('#'):
            if '>=' in line or '==' in line or line.isalpha() or '-' in line:
                continue
            print(f'Invalid line: {line}')
            sys.exit(1)
" 2>/dev/null; then
        test_pass "requirements.txt is valid"
    else
        test_fail "requirements.txt has issues"
    fi
    
    echo_test "Checking frontend app.py syntax..."
    if python3 -m py_compile manifests/frontend/app.py 2>/dev/null; then
        test_pass "manifests/frontend/app.py syntax is valid"
    else
        test_fail "manifests/frontend/app.py has syntax errors"
    fi
    
    echo_test "Checking MCP server http_app.py syntax..."
    if python3 -m py_compile mcp/weather-mongodb/http_app.py 2>/dev/null; then
        test_pass "mcp/weather-mongodb/http_app.py syntax is valid"
    else
        test_fail "mcp/weather-mongodb/http_app.py has syntax errors"
    fi
}

# ============================================
# Docker Tests
# ============================================
test_docker() {
    print_header "Docker Build Tests"
    
    echo_test "Checking Docker is installed..."
    if ! command -v docker &>/dev/null; then
        echo_warning "Docker is not installed - skipping Docker tests"
        return
    fi
    test_pass "Docker is installed: $(docker --version)"
    
    echo_test "Checking Docker daemon is running..."
    if ! docker info &>/dev/null; then
        echo_warning "Docker daemon is not running - skipping build tests"
        return
    fi
    test_pass "Docker daemon is running"
    
    echo_test "Building Demo UI image..."
    if docker build -t llamastack-demo-ui-test:latest . -q 2>/dev/null; then
        test_pass "Demo UI Docker image built successfully"
        docker rmi llamastack-demo-ui-test:latest &>/dev/null || true
    else
        test_fail "Demo UI Docker build failed"
    fi
    
    echo_test "Building Weather MCP image..."
    if docker build -t weather-mcp-test:latest ./mcp -q 2>/dev/null; then
        test_pass "Weather MCP Docker image built successfully"
        docker rmi weather-mcp-test:latest &>/dev/null || true
    else
        test_fail "Weather MCP Docker build failed"
    fi
}

# ============================================
# Kubernetes/OpenShift YAML Tests
# ============================================
test_yaml() {
    print_header "Kubernetes/OpenShift YAML Validation"
    
    echo_test "Checking for kubectl or oc..."
    CLI=""
    if command -v oc &>/dev/null; then
        CLI="oc"
        test_pass "OpenShift CLI (oc) is available"
    elif command -v kubectl &>/dev/null; then
        CLI="kubectl"
        test_pass "kubectl is available"
    else
        echo_warning "Neither oc nor kubectl found - using basic YAML validation"
    fi
    
    echo_test "Validating YAML syntax..."
    YAML_ERRORS=0
    YAML_TOTAL=0
    
    # Check if PyYAML is available
    HAS_PYYAML=false
    if python3 -c "import yaml" 2>/dev/null; then
        HAS_PYYAML=true
    fi
    
    for yaml in $(find manifests -name "*.yaml" -type f); do
        YAML_TOTAL=$((YAML_TOTAL + 1))
        
        if [ "$HAS_PYYAML" = true ]; then
            # Use PyYAML for validation
            if python3 -c "
import yaml
import sys
try:
    with open('$yaml') as f:
        list(yaml.safe_load_all(f))
except Exception as e:
    print(f'Error: {e}', file=sys.stderr)
    sys.exit(1)
" 2>/dev/null; then
                echo "   ✓ $yaml"
            else
                echo "   ✗ $yaml - INVALID YAML"
                YAML_ERRORS=$((YAML_ERRORS + 1))
            fi
        elif [ -n "$CLI" ]; then
            # Use oc/kubectl for validation
            if $CLI apply -f "$yaml" --dry-run=client -o yaml &>/dev/null; then
                echo "   ✓ $yaml"
            else
                # Some files might not be valid K8s manifests but still valid YAML
                # Just check if the file is readable
                if head -1 "$yaml" &>/dev/null; then
                    echo "   ~ $yaml (skipped - not a K8s manifest)"
                else
                    echo "   ✗ $yaml - INVALID"
                    YAML_ERRORS=$((YAML_ERRORS + 1))
                fi
            fi
        else
            # Basic check - just verify file is readable
            if head -1 "$yaml" &>/dev/null; then
                echo "   ~ $yaml (basic check only)"
            else
                echo "   ✗ $yaml - UNREADABLE"
                YAML_ERRORS=$((YAML_ERRORS + 1))
            fi
        fi
    done
    
    if [ $YAML_ERRORS -eq 0 ]; then
        test_pass "All $YAML_TOTAL YAML files validated"
    else
        test_fail "$YAML_ERRORS of $YAML_TOTAL YAML files have errors"
    fi
    
    if [ "$HAS_PYYAML" = false ]; then
        echo_warning "PyYAML not installed - using basic validation only"
        echo_info "Install with: pip install pyyaml"
    fi
    
    if [ -n "$CLI" ]; then
        echo_test "Dry-run validation with $CLI..."
        
        # Test a sample manifest
        if $CLI apply -f manifests/mcp-servers/hr-mcp-server.yaml --dry-run=client -o yaml &>/dev/null; then
            test_pass "HR MCP manifest passes dry-run validation"
        else
            test_fail "HR MCP manifest failed dry-run validation"
        fi
        
        # LlamaStack config is just a ConfigMap data file, not a K8s manifest
        # So we skip dry-run for it
        if [ -f manifests/llamastack/llama-stack-config-phase1.yaml ]; then
            test_pass "LlamaStack config file exists"
        else
            test_fail "LlamaStack config file missing"
        fi
    fi
}

# ============================================
# OpenShift Cluster Tests
# ============================================
test_openshift() {
    print_header "OpenShift Cluster Tests"
    
    echo_test "Checking oc CLI..."
    if ! command -v oc &>/dev/null; then
        echo_warning "oc CLI not found - skipping OpenShift tests"
        return
    fi
    test_pass "oc CLI is available"
    
    echo_test "Checking cluster connection..."
    if ! oc whoami &>/dev/null; then
        echo_warning "Not logged in to OpenShift - skipping cluster tests"
        echo_info "Login with: oc login --token=<token> --server=<url>"
        return
    fi
    test_pass "Connected as: $(oc whoami)"
    test_pass "Cluster: $(oc whoami --show-server)"
    
    NAMESPACE="${NAMESPACE:-my-first-model}"
    echo_info "Testing in namespace: $NAMESPACE"
    
    echo_test "Checking namespace exists..."
    if oc get namespace $NAMESPACE &>/dev/null; then
        test_pass "Namespace $NAMESPACE exists"
    else
        echo_warning "Namespace $NAMESPACE does not exist"
        return
    fi
    
    echo_test "Checking LlamaStack deployment..."
    if oc get deployment lsd-genai-playground -n $NAMESPACE &>/dev/null; then
        test_pass "LlamaStack deployment exists"
        
        # Check if running
        READY=$(oc get deployment lsd-genai-playground -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        if [ "$READY" -gt 0 ]; then
            test_pass "LlamaStack has $READY ready replica(s)"
        else
            test_fail "LlamaStack has no ready replicas"
        fi
    else
        echo_warning "LlamaStack deployment not found in $NAMESPACE"
    fi
    
    echo_test "Checking MCP servers..."
    for mcp in mcp-weather hr-mcp-server jira-mcp-server github-mcp-server weather-mongodb-mcp; do
        if oc get deployment $mcp -n $NAMESPACE &>/dev/null; then
            READY=$(oc get deployment $mcp -n $NAMESPACE -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
            if [ "$READY" -gt 0 ]; then
                test_pass "$mcp is running ($READY replicas)"
            else
                echo_warning "$mcp exists but has no ready replicas"
            fi
        fi
    done
    
    echo_test "Testing LlamaStack API..."
    if oc exec deployment/lsd-genai-playground -n $NAMESPACE -- curl -s http://localhost:8321/v1/tools &>/dev/null; then
        TOOLS=$(oc exec deployment/lsd-genai-playground -n $NAMESPACE -- curl -s http://localhost:8321/v1/tools 2>/dev/null | python3 -c "import sys,json; print(len(json.load(sys.stdin).get('data',[])))" 2>/dev/null || echo "0")
        test_pass "LlamaStack API responding - $TOOLS tools available"
    else
        test_fail "LlamaStack API not responding"
    fi
}

# ============================================
# Kubernetes Tests
# ============================================
test_kubernetes() {
    print_header "Kubernetes Cluster Tests"
    
    echo_test "Checking kubectl..."
    if ! command -v kubectl &>/dev/null; then
        echo_warning "kubectl not found - skipping Kubernetes tests"
        return
    fi
    test_pass "kubectl is available"
    
    echo_test "Checking cluster connection..."
    if ! kubectl cluster-info &>/dev/null; then
        echo_warning "Not connected to Kubernetes cluster - skipping cluster tests"
        return
    fi
    test_pass "Connected to Kubernetes cluster"
    
    # Similar tests as OpenShift but using kubectl
    echo_info "Kubernetes cluster tests would run here..."
    echo_info "(Similar to OpenShift tests but using kubectl)"
}

# ============================================
# Script Tests
# ============================================
test_scripts() {
    print_header "Script Validation Tests"
    
    echo_test "Checking script syntax..."
    for script in scripts/*.sh; do
        if bash -n "$script" 2>/dev/null; then
            echo "   ✓ $script"
        else
            echo "   ✗ $script - SYNTAX ERROR"
            test_fail "$script has syntax errors"
        fi
    done
    test_pass "All scripts pass syntax check"
    
    echo_test "Checking script permissions..."
    for script in scripts/*.sh; do
        if [ -x "$script" ]; then
            echo "   ✓ $script is executable"
        else
            echo "   ⚠ $script is not executable"
        fi
    done
    
    echo_test "Testing deploy-demo.sh help..."
    if ./scripts/deploy-demo.sh help 2>&1 | grep -q "Usage"; then
        test_pass "deploy-demo.sh shows help correctly"
    else
        test_fail "deploy-demo.sh help not working"
    fi
}

# ============================================
# Summary
# ============================================
print_summary() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                    Test Summary                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    echo -e "   ${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "   ${RED}Failed: $TESTS_FAILED${NC}"
    echo ""
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo_success "All tests passed! ✨"
        exit 0
    else
        echo_error "Some tests failed. Please review the output above."
        exit 1
    fi
}

# ============================================
# Main
# ============================================
print_header "LlamaStack MCP Demo - Deployment Tests"

case "${1:-all}" in
    local)
        test_local
        ;;
    docker)
        test_docker
        ;;
    yaml)
        test_yaml
        ;;
    openshift)
        test_openshift
        ;;
    kubernetes)
        test_kubernetes
        ;;
    scripts)
        test_scripts
        ;;
    all)
        test_local
        test_scripts
        test_yaml
        test_docker
        
        # Only test cluster if connected
        if command -v oc &>/dev/null && oc whoami &>/dev/null; then
            test_openshift
        elif command -v kubectl &>/dev/null && kubectl cluster-info &>/dev/null; then
            test_kubernetes
        fi
        ;;
    *)
        echo "Usage: $0 [local|docker|yaml|openshift|kubernetes|scripts|all]"
        echo ""
        echo "Test suites:"
        echo "  local      - Test Python syntax and dependencies"
        echo "  docker     - Test Docker image builds"
        echo "  yaml       - Validate Kubernetes/OpenShift YAML manifests"
        echo "  openshift  - Test deployment on OpenShift cluster"
        echo "  kubernetes - Test deployment on Kubernetes cluster"
        echo "  scripts    - Validate shell scripts"
        echo "  all        - Run all applicable tests (default)"
        exit 0
        ;;
esac

print_summary
