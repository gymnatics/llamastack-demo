# Weather Data MCP Server - Kubernetes/Docker Version
# Uses public Python image (no authentication required)

FROM python:3.12-slim

WORKDIR /app

# Install dependencies
RUN pip install --no-cache-dir mcp motor uvicorn

# Copy application
COPY http_app.py .

# Environment variables (override these in your deployment)
ENV MCP_SERVER_NAME="weather-data" \
    MONGODB_URL="mongodb://localhost:27017" \
    DATABASE_NAME="weather" \
    COLLECTION_NAME="observations"

EXPOSE 8000

CMD ["python", "http_app.py"]
