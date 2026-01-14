# LlamaStack Multi-MCP Demo UI - Kubernetes/Docker Version
# Uses public Python image (no authentication required)
#
# Build: docker build -t llamastack-demo-ui .
# Run:   docker run -p 8501:8501 -e LLAMASTACK_URL=http://host:8321 llamastack-demo-ui

FROM python:3.12-slim

WORKDIR /app

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy app from new location
COPY manifests/frontend/app.py .

EXPOSE 8501

# Environment variables
ENV LLAMASTACK_URL="http://localhost:8321" \
    MODEL_ID="qwen3-4b" \
    ADMIN_MODE="false"

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -f http://localhost:8501/_stcore/health || exit 1

# Run Streamlit
CMD ["streamlit", "run", "app.py", "--server.port=8501", "--server.address=0.0.0.0", "--server.headless=true", "--browser.gatherUsageStats=false"]
