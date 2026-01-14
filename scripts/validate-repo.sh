#!/bin/bash
# Repository Validation Script
# Run this to verify the repository structure is correct

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

cd "$REPO_DIR"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║       LlamaStack MCP Demo - Repository Validation          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

ERRORS=0

# Function to check file exists
check_file() {
    if [ -f "$1" ]; then
        echo "   ✅ $1"
    else
        echo "   ❌ $1 - MISSING!"
        ERRORS=$((ERRORS + 1))
    fi
}

# Function to check directory exists
check_dir() {
    if [ -d "$1" ]; then
        echo "   ✅ $1/"
    else
        echo "   ❌ $1/ - MISSING!"
        ERRORS=$((ERRORS + 1))
    fi
}

echo "📁 Checking directory structure..."
check_dir "docs"
check_dir "manifests"
check_dir "manifests/frontend"
check_dir "manifests/llamastack"
check_dir "manifests/mcp-servers"
check_dir "mcp/weather-mongodb"
check_dir "scripts"

echo ""
echo "📄 Checking core files..."
check_file "README.md"
check_file "requirements.txt"
check_file "Dockerfile"
check_file "Dockerfile.openshift"

echo ""
echo "📄 Checking documentation..."
check_file "docs/DEMO-GUIDE.md"
check_file "docs/PRD.md"
check_file "docs/PROJECT-LOG.md"

echo ""
echo "📄 Checking frontend files..."
check_file "manifests/frontend/app.py"
check_file "manifests/frontend/deployment.yaml"

echo ""
echo "📄 Checking LlamaStack configs..."
check_file "manifests/llamastack/llama-stack-config-phase1.yaml"
check_file "manifests/llamastack/llama-stack-config-phase2.yaml"
check_file "manifests/llamastack/llama-stack-config-full.yaml"

echo ""
echo "📄 Checking MCP server manifests..."
check_file "manifests/mcp-servers/hr-mcp-server.yaml"
check_file "manifests/mcp-servers/jira-mcp-server.yaml"
check_file "manifests/mcp-servers/github-mcp-server.yaml"
check_file "manifests/mcp-servers/weather-mongodb/deploy-weather-mongodb.yaml"

echo ""
echo "📄 Checking MongoDB Weather MCP source..."
check_file "mcp/weather-mongodb/http_app.py"
check_file "mcp/weather-mongodb/sample_data.py"
check_file "mcp/Dockerfile"
check_file "mcp/Dockerfile.openshift"

echo ""
echo "📜 Checking scripts..."
check_file "scripts/deploy-demo.sh"

echo ""
echo "🔍 Validating Dockerfile references..."

# Check root Dockerfile
if grep -q "COPY manifests/frontend/app.py" Dockerfile; then
    echo "   ✅ Dockerfile references correct app.py path"
else
    echo "   ❌ Dockerfile has incorrect app.py path"
    ERRORS=$((ERRORS + 1))
fi

# Check mcp Dockerfile
if grep -q "COPY weather-mongodb/http_app.py" mcp/Dockerfile; then
    echo "   ✅ mcp/Dockerfile references correct http_app.py path"
else
    echo "   ❌ mcp/Dockerfile has incorrect http_app.py path"
    ERRORS=$((ERRORS + 1))
fi

echo ""
echo "📜 Validating script syntax..."
for script in scripts/*.sh; do
    if bash -n "$script" 2>/dev/null; then
        echo "   ✅ $script - syntax OK"
    else
        echo "   ❌ $script - syntax ERROR"
        ERRORS=$((ERRORS + 1))
    fi
done

echo ""
echo "════════════════════════════════════════════════════════════"
if [ $ERRORS -eq 0 ]; then
    echo "✅ All validations passed! Repository is ready to use."
    echo ""
    echo "Quick start:"
    echo "  ./scripts/deploy-demo.sh config    # Show current config"
    echo "  ./scripts/deploy-demo.sh add hr    # Add HR MCP"
    echo "  ./scripts/deploy-demo.sh tools     # List tools"
else
    echo "❌ Found $ERRORS error(s). Please fix before using."
fi
echo "════════════════════════════════════════════════════════════"
echo ""

exit $ERRORS
