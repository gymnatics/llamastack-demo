# Weather Data MCP Server (MongoDB) - Kubernetes/Docker Version
# Uses public Python image (no authentication required)
#
# Build: docker build -t weather-mcp-server ./mcp
# Run:   docker run -p 8000:8000 -e MONGODB_URL=mongodb://host:27017 weather-mcp-server

FROM python:3.12-slim

WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir mcp motor uvicorn

# Copy application from weather-mongodb subfolder
COPY weather-mongodb/http_app.py .

# Environment variables (override these in your deployment)
ENV MCP_SERVER_NAME="weather-mongodb" \
    MONGODB_URL="mongodb://localhost:27017" \
    DATABASE_NAME="weather" \
    COLLECTION_NAME="observations"

EXPOSE 8000

CMD ["python", "http_app.py"]
