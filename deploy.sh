#!/bin/bash
################################################################################
# LlamaStack MCP Demo - Universal Deployment Script
################################################################################
# Supports:
# - OpenShift (oc)
# - Vanilla Kubernetes (kubectl)
# - Local Docker Compose
#
# Deploys:
# - MongoDB with sample weather data
# - Weather MCP Server
# - Streamlit Demo UI
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

################################################################################
# Platform Selection
################################################################################
echo -e "${CYAN}Select your deployment platform:${NC}"
echo ""
echo "1) OpenShift (uses oc CLI)"
echo "2) Kubernetes (uses kubectl)"
echo "3) Local Docker (uses docker-compose)"
echo ""
read -p "Enter your choice [1]: " platform_choice
platform_choice="${platform_choice:-1}"

case $platform_choice in
    1) PLATFORM="openshift"; CLI="oc" ;;
    2) PLATFORM="kubernetes"; CLI="kubectl" ;;
    3) PLATFORM="docker"; CLI="docker" ;;
    *) print_error "Invalid choice"; exit 1 ;;
esac

################################################################################
# OpenShift Deployment
################################################################################
deploy_openshift() {
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

    # Helper function to apply manifests with namespace substitution
    apply_manifest() {
        local file="$1"
        sed -e "s/namespace: demo-test/namespace: $TARGET_NS/g" \
            -e "s/NAMESPACE_PLACEHOLDER/$TARGET_NS/g" \
            -e "s|demo-test/|$TARGET_NS/|g" \
            "$file" | oc apply -f -
    }

    # Deploy MongoDB
    deploy_mongodb_openshift() {
        print_step "Deploying MongoDB..."
        if oc get pvc mongodb-data -n "$TARGET_NS" &>/dev/null; then
            print_info "MongoDB PVC already exists, skipping PVC creation"
        fi
        apply_manifest "$SCRIPT_DIR/mcp/mongodb-deployment.yaml"
        
        print_step "Waiting for MongoDB to be ready..."
        oc wait --for=condition=available deployment/mongodb -n "$TARGET_NS" --timeout=180s 2>/dev/null || true
        print_success "MongoDB deployed"
        
        # Initialize data
        print_step "Initializing sample weather data..."
        oc delete job init-weather-data -n "$TARGET_NS" 2>/dev/null || true
        apply_manifest "$SCRIPT_DIR/mcp/init-data-job.yaml"
        oc wait --for=condition=complete job/init-weather-data -n "$TARGET_NS" --timeout=120s 2>/dev/null || true
        print_success "Sample data loaded"
    }

    # Deploy MCP Server
    deploy_mcp_openshift() {
        print_step "Building Weather MCP Server..."
        apply_manifest "$SCRIPT_DIR/mcp/buildconfig.yaml"
        oc start-build weather-mcp-server --from-dir="$SCRIPT_DIR/mcp" --follow -n "$TARGET_NS"
        
        print_step "Deploying Weather MCP Server..."
        apply_manifest "$SCRIPT_DIR/mcp/deployment.yaml"
        oc rollout status deployment/weather-mcp-server -n "$TARGET_NS" --timeout=120s 2>/dev/null || true
        print_success "Weather MCP Server deployed"
    }

    # Deploy Demo UI
    deploy_ui_openshift() {
        # Get configuration
        local default_llamastack_url="http://lsd-genai-playground-service.${TARGET_NS}.svc.cluster.local:8321"
        echo ""
        read -p "LlamaStack URL [$default_llamastack_url]: " LLAMASTACK_URL
        LLAMASTACK_URL="${LLAMASTACK_URL:-$default_llamastack_url}"
        
        read -p "Model ID [qwen3-8b]: " MODEL_ID
        MODEL_ID="${MODEL_ID:-qwen3-8b}"
        
        local mcp_url="http://weather-mcp-server.${TARGET_NS}.svc.cluster.local:8000"
        
        print_step "Applying ConfigMap..."
        sed -e "s/namespace: demo-test/namespace: $TARGET_NS/g" \
            -e "s|demo-test/|$TARGET_NS/|g" \
            -e "s|LLAMASTACK_URL:.*|LLAMASTACK_URL: \"$LLAMASTACK_URL\"|g" \
            -e "s|MODEL_ID:.*|MODEL_ID: \"$MODEL_ID\"|g" \
            -e "s|MCP_SERVER_URL:.*|MCP_SERVER_URL: \"$mcp_url\"|g" \
            "$SCRIPT_DIR/deployment.yaml" | oc apply -f -
        
        print_step "Building Demo UI..."
        apply_manifest "$SCRIPT_DIR/buildconfig.yaml"
        oc start-build llamastack-mcp-demo --from-dir="$SCRIPT_DIR" --follow -n "$TARGET_NS"
        
        oc rollout status deployment/llamastack-mcp-demo -n "$TARGET_NS" --timeout=120s 2>/dev/null || true
        print_success "Demo UI deployed"
        
        route_url=$(oc get route llamastack-mcp-demo -n "$TARGET_NS" -o jsonpath='{.spec.host}' 2>/dev/null)
        if [ -n "$route_url" ]; then
            echo ""
            echo -e "${GREEN}🌐 Demo UI: https://$route_url${NC}"
        fi
    }

    # Deployment menu
    echo ""
    echo -e "${CYAN}What would you like to deploy?${NC}"
    echo "1) Complete Stack (MongoDB + MCP Server + Demo UI)"
    echo "2) MCP Server + MongoDB only"
    echo "3) Demo UI only"
    echo ""
    read -p "Enter your choice [1]: " deploy_choice
    deploy_choice="${deploy_choice:-1}"

    case $deploy_choice in
        1) deploy_mongodb_openshift; deploy_mcp_openshift; deploy_ui_openshift ;;
        2) deploy_mongodb_openshift; deploy_mcp_openshift ;;
        3) deploy_ui_openshift ;;
        *) print_error "Invalid choice"; exit 1 ;;
    esac

    # Print MCP registration info
    echo ""
    echo -e "${YELLOW}📝 Register MCP with LlamaStack:${NC}"
    echo "   Add to your LlamaStack config under tool_groups:"
    echo ""
    echo "   - toolgroup_id: mcp::weather-data"
    echo "     provider_id: model-context-protocol"
    echo "     mcp_endpoint:"
    echo "       uri: http://weather-mcp-server.$TARGET_NS.svc.cluster.local:8000/mcp"
}

################################################################################
# Kubernetes Deployment
################################################################################
deploy_kubernetes() {
    if ! command -v kubectl &>/dev/null; then
        print_error "kubectl not found. Please install kubectl."
        exit 1
    fi

    # Check connection
    if ! kubectl cluster-info &>/dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        echo "Please configure kubectl to connect to your cluster"
        exit 1
    fi

    print_success "Connected to Kubernetes cluster"

    # Get namespace
    CURRENT_NS=$(kubectl config view --minify -o jsonpath='{..namespace}' 2>/dev/null)
    CURRENT_NS="${CURRENT_NS:-default}"
    echo ""
    read -p "Target namespace [$CURRENT_NS]: " TARGET_NS
    TARGET_NS="${TARGET_NS:-$CURRENT_NS}"

    # Create namespace if needed
    if ! kubectl get namespace "$TARGET_NS" &>/dev/null; then
        print_step "Creating namespace $TARGET_NS..."
        kubectl create namespace "$TARGET_NS"
    fi

    # Check for container registry
    echo ""
    echo -e "${YELLOW}Kubernetes requires pre-built images.${NC}"
    echo "You need to build and push images to a registry first."
    echo ""
    read -p "Container registry (e.g., docker.io/myuser): " REGISTRY
    
    if [ -z "$REGISTRY" ]; then
        print_error "Registry is required for Kubernetes deployment"
        echo ""
        echo "Build and push images first:"
        echo "  docker build -t <registry>/weather-mcp-server:latest ./mcp"
        echo "  docker build -t <registry>/llamastack-mcp-demo:latest ."
        echo "  docker push <registry>/weather-mcp-server:latest"
        echo "  docker push <registry>/llamastack-mcp-demo:latest"
        exit 1
    fi

    # Helper function
    apply_manifest_k8s() {
        local file="$1"
        # Remove OpenShift-specific resources and update namespace/images
        sed -e "s/namespace: demo-test/namespace: $TARGET_NS/g" \
            -e "s|image-registry.openshift-image-registry.svc:5000/demo-test/|$REGISTRY/|g" \
            -e "s|demo-test/|$TARGET_NS/|g" \
            "$file" | grep -v "^kind: Route$" -A 20 | kubectl apply -f - 2>/dev/null || \
        sed -e "s/namespace: demo-test/namespace: $TARGET_NS/g" \
            -e "s|image-registry.openshift-image-registry.svc:5000/demo-test/|$REGISTRY/|g" \
            "$file" | kubectl apply -f -
    }

    # Deploy MongoDB
    print_step "Deploying MongoDB..."
    apply_manifest_k8s "$SCRIPT_DIR/mcp/mongodb-deployment.yaml"
    kubectl wait --for=condition=available deployment/mongodb -n "$TARGET_NS" --timeout=180s 2>/dev/null || true
    print_success "MongoDB deployed"

    # Deploy MCP Server (assumes image is already built)
    print_step "Deploying Weather MCP Server..."
    sed -e "s/namespace: demo-test/namespace: $TARGET_NS/g" \
        -e "s|image-registry.openshift-image-registry.svc:5000/demo-test/weather-mcp-server:latest|$REGISTRY/weather-mcp-server:latest|g" \
        "$SCRIPT_DIR/mcp/deployment.yaml" | kubectl apply -f -
    print_success "Weather MCP Server deployed"

    # Deploy Demo UI
    echo ""
    read -p "LlamaStack URL [http://llamastack:8321]: " LLAMASTACK_URL
    LLAMASTACK_URL="${LLAMASTACK_URL:-http://llamastack:8321}"
    read -p "Model ID [llama3.1:8b]: " MODEL_ID
    MODEL_ID="${MODEL_ID:-llama3.1:8b}"

    print_step "Deploying Demo UI..."
    sed -e "s/namespace: demo-test/namespace: $TARGET_NS/g" \
        -e "s|image-registry.openshift-image-registry.svc:5000/demo-test/llamastack-mcp-demo:latest|$REGISTRY/llamastack-mcp-demo:latest|g" \
        -e "s|LLAMASTACK_URL:.*|LLAMASTACK_URL: \"$LLAMASTACK_URL\"|g" \
        -e "s|MODEL_ID:.*|MODEL_ID: \"$MODEL_ID\"|g" \
        "$SCRIPT_DIR/deployment.yaml" | grep -v "kind: Route" -A 15 | kubectl apply -f - 2>/dev/null || true
    print_success "Demo UI deployed"

    echo ""
    echo -e "${YELLOW}📝 To expose the Demo UI, create an Ingress or use port-forward:${NC}"
    echo "   kubectl port-forward svc/llamastack-mcp-demo 8501:8501 -n $TARGET_NS"
    echo "   Then open: http://localhost:8501"
}

################################################################################
# Local Docker Deployment
################################################################################
deploy_docker() {
    if ! command -v docker &>/dev/null; then
        print_error "Docker not found. Please install Docker."
        exit 1
    fi

    echo ""
    echo -e "${CYAN}Local Docker deployment will run:${NC}"
    echo "  • MongoDB on port 27017"
    echo "  • Weather MCP Server on port 8000"
    echo "  • Demo UI on port 8501"
    echo ""

    # Check if docker-compose exists, if not create it
    if [ ! -f "$SCRIPT_DIR/docker-compose.yaml" ]; then
        print_step "Creating docker-compose.yaml..."
        cat > "$SCRIPT_DIR/docker-compose.yaml" << 'COMPOSE_EOF'
version: '3.8'

services:
  mongodb:
    image: mongo:6.0
    container_name: mongodb
    ports:
      - "27017:27017"
    volumes:
      - mongodb_data:/data/db

  mcp-server:
    build:
      context: ./mcp
      dockerfile: Dockerfile
    container_name: weather-mcp-server
    ports:
      - "8000:8000"
    environment:
      - MONGODB_URL=mongodb://mongodb:27017
      - MCP_SERVER_NAME=weather-data
      - DATABASE_NAME=weather
      - COLLECTION_NAME=observations
    depends_on:
      - mongodb

  demo-ui:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: llamastack-demo-ui
    ports:
      - "8501:8501"
    environment:
      - LLAMASTACK_URL=${LLAMASTACK_URL:-http://host.docker.internal:8321}
      - MODEL_ID=${MODEL_ID:-llama3.1:8b}
      - MCP_SERVER_URL=http://mcp-server:8000
    depends_on:
      - mcp-server

volumes:
  mongodb_data:
COMPOSE_EOF
        print_success "Created docker-compose.yaml"
    fi

    # Get LlamaStack configuration
    echo ""
    echo -e "${CYAN}LlamaStack Configuration:${NC}"
    echo "If running LlamaStack locally, use: http://host.docker.internal:8321"
    echo ""
    read -p "LlamaStack URL [http://host.docker.internal:8321]: " LLAMASTACK_URL
    export LLAMASTACK_URL="${LLAMASTACK_URL:-http://host.docker.internal:8321}"
    
    read -p "Model ID [llama3.1:8b]: " MODEL_ID
    export MODEL_ID="${MODEL_ID:-llama3.1:8b}"

    # Start services
    print_step "Building and starting containers..."
    cd "$SCRIPT_DIR"
    docker-compose up -d --build

    # Wait for MongoDB
    print_step "Waiting for MongoDB to be ready..."
    sleep 5

    # Load sample data directly via mongosh
    print_step "Loading sample weather data..."
    docker exec -i mongodb mongosh weather --eval '
    db.observations.drop();
    db.observations.insertMany([
      {station_id: "KJFK", station_name: "John F. Kennedy International", location: {city: "New York", country: "USA", coordinates: {lat: 40.6413, lon: -73.7781}}, timestamp: new Date(), temperature: 22, humidity: 65, wind_speed: 15, conditions: "Partly Cloudy"},
      {station_id: "EGLL", station_name: "London Heathrow Airport", location: {city: "London", country: "UK", coordinates: {lat: 51.4700, lon: -0.4543}}, timestamp: new Date(), temperature: 12, humidity: 78, wind_speed: 8, conditions: "Overcast"},
      {station_id: "RJTT", station_name: "Tokyo Haneda Airport", location: {city: "Tokyo", country: "Japan", coordinates: {lat: 35.5494, lon: 139.7798}}, timestamp: new Date(), temperature: 18, humidity: 55, wind_speed: 12, conditions: "Clear"},
      {station_id: "YSSY", station_name: "Sydney Kingsford Smith Airport", location: {city: "Sydney", country: "Australia", coordinates: {lat: -33.9399, lon: 151.1753}}, timestamp: new Date(), temperature: 28, humidity: 45, wind_speed: 20, conditions: "Sunny"},
      {station_id: "WSSS", station_name: "Singapore Changi Airport", location: {city: "Singapore", country: "Singapore", coordinates: {lat: 1.3644, lon: 103.9915}}, timestamp: new Date(), temperature: 31, humidity: 85, wind_speed: 5, conditions: "Thunderstorms"},
      {station_id: "VIDP", station_name: "Delhi Indira Gandhi International", location: {city: "New Delhi", country: "India", coordinates: {lat: 28.5665, lon: 77.1031}}, timestamp: new Date(), temperature: 35, humidity: 40, wind_speed: 10, conditions: "Hazy"},
      {station_id: "OMDB", station_name: "Dubai International Airport", location: {city: "Dubai", country: "UAE", coordinates: {lat: 25.2532, lon: 55.3657}}, timestamp: new Date(), temperature: 38, humidity: 30, wind_speed: 18, conditions: "Clear"},
      {station_id: "LFPG", station_name: "Paris Charles de Gaulle Airport", location: {city: "Paris", country: "France", coordinates: {lat: 49.0097, lon: 2.5479}}, timestamp: new Date(), temperature: 15, humidity: 70, wind_speed: 12, conditions: "Cloudy"}
    ]);
    print("✓ Loaded " + db.observations.countDocuments() + " weather stations");
    ' 2>/dev/null || print_warning "Could not auto-load data"
    print_success "Sample data loaded"

    echo ""
    print_header "Local Deployment Complete!"
    echo ""
    echo -e "${GREEN}Services running:${NC}"
    echo "  • MongoDB:        mongodb://localhost:27017"
    echo "  • MCP Server:     http://localhost:8000"
    echo "  • Demo UI:        http://localhost:8501"
    echo ""
    echo -e "${YELLOW}📝 To use with LlamaStack:${NC}"
    echo ""
    echo "1. Start LlamaStack with MCP configured:"
    echo ""
    echo "   Add to your run.yaml:"
    echo "   tool_groups:"
    echo "   - toolgroup_id: mcp::weather-data"
    echo "     provider_id: model-context-protocol"
    echo "     mcp_endpoint:"
    echo "       uri: http://localhost:8000/mcp"
    echo ""
    echo "2. Then run: llama stack run run.yaml --port 8321"
    echo ""
    echo -e "${CYAN}Commands:${NC}"
    echo "  Stop:    docker-compose down"
    echo "  Logs:    docker-compose logs -f"
    echo "  Restart: docker-compose restart"
}

################################################################################
# Main
################################################################################
case $PLATFORM in
    openshift) deploy_openshift ;;
    kubernetes) deploy_kubernetes ;;
    docker) deploy_docker ;;
esac

echo ""
print_success "Deployment complete!"
