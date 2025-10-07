# Azure MCP HTTP Host - Docker Hub Deployment Examples

## Basic Usage

### 1. Build and Push to Docker Hub
```powershell
# Basic deployment
./Deploy-DockerHub.ps1 -DockerHubUsername "myusername"

# Custom image name and tag
./Deploy-DockerHub.ps1 -DockerHubUsername "myusername" -ImageName "my-mcp-server" -ImageTag "v1.0.0"

# Build only (don't push)
./Deploy-DockerHub.ps1 -DockerHubUsername "myusername" -BuildOnly

# Multi-platform build (AMD64 + ARM64)
./Deploy-DockerHub.ps1 -DockerHubUsername "myusername" -MultiPlatform
```

### 2. Using Access Tokens (CI/CD)
```powershell
# Set your Docker Hub access token
$env:DOCKER_HUB_TOKEN = "dckr_pat_YOUR_TOKEN_HERE"

# Deploy using token
./Deploy-DockerHub.ps1 -DockerHubUsername "myusername" -DockerHubToken $env:DOCKER_HUB_TOKEN
```

## Running the Container

### Local Testing
```bash
# Pull and run from Docker Hub
docker run -p 5001:5001 myusername/azure-mcp-http-host:latest

# Run with custom environment
docker run -p 5001:5001 \
  -e ASPNETCORE_ENVIRONMENT=Development \
  -e ASPNETCORE_URLS=http://0.0.0.0:5001 \
  --name azure-mcp-host \
  myusername/azure-mcp-http-host:latest

# Run in background
docker run -d -p 5001:5001 --name azure-mcp-host myusername/azure-mcp-http-host:latest
```

### Docker Compose
```yaml
# docker-compose.yml
version: '3.8'
services:
  azure-mcp-host:
    image: myusername/azure-mcp-http-host:latest
    ports:
      - "5001:5001"
    environment:
      - ASPNETCORE_ENVIRONMENT=Production
      - ASPNETCORE_URLS=http://0.0.0.0:5001
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5001/"]
      interval: 30s
      timeout: 10s
      retries: 3
```

## Cloud Deployment Examples

### AWS ECS/Fargate
```json
{
  "family": "azure-mcp-host",
  "taskDefinition": {
    "containerDefinitions": [
      {
        "name": "azure-mcp-host",
        "image": "myusername/azure-mcp-http-host:latest",
        "portMappings": [
          {
            "containerPort": 5001,
            "protocol": "tcp"
          }
        ],
        "environment": [
          {
            "name": "ASPNETCORE_URLS",
            "value": "http://0.0.0.0:5001"
          }
        ]
      }
    ]
  }
}
```

### Google Cloud Run
```bash
# Deploy to Google Cloud Run
gcloud run deploy azure-mcp-host \
  --image=myusername/azure-mcp-http-host:latest \
  --platform=managed \
  --port=5001 \
  --allow-unauthenticated \
  --region=us-central1
```

### Azure Container Instances
```bash
# Deploy to Azure Container Instances
az container create \
  --resource-group myResourceGroup \
  --name azure-mcp-host \
  --image myusername/azure-mcp-http-host:latest \
  --dns-name-label azure-mcp-host-unique \
  --ports 5001 \
  --environment-variables ASPNETCORE_URLS=http://0.0.0.0:5001
```

### Kubernetes
```yaml
# kubernetes.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: azure-mcp-host
spec:
  replicas: 2
  selector:
    matchLabels:
      app: azure-mcp-host
  template:
    metadata:
      labels:
        app: azure-mcp-host
    spec:
      containers:
      - name: azure-mcp-host
        image: myusername/azure-mcp-http-host:latest
        ports:
        - containerPort: 5001
        env:
        - name: ASPNETCORE_URLS
          value: "http://0.0.0.0:5001"
        resources:
          requests:
            memory: "512Mi"
            cpu: "250m"
          limits:
            memory: "1Gi"
            cpu: "500m"
---
apiVersion: v1
kind: Service
metadata:
  name: azure-mcp-host-service
spec:
  selector:
    app: azure-mcp-host
  ports:
  - port: 80
    targetPort: 5001
  type: LoadBalancer
```

## CI/CD Integration

### GitHub Actions
```yaml
# .github/workflows/docker-publish.yml
name: Build and Push to Docker Hub

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

env:
  IMAGE_NAME: azure-mcp-http-host

jobs:
  build-and-push:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v4
    
    - name: Set up PowerShell
      uses: actions/setup-powershell@v1
    
    - name: Build and push Docker image
      env:
        DOCKER_HUB_USERNAME: ${{ secrets.DOCKER_HUB_USERNAME }}
        DOCKER_HUB_TOKEN: ${{ secrets.DOCKER_HUB_TOKEN }}
      run: |
        ./servers/Azure.Mcp.Server/HttpHost/Deploy-DockerHub.ps1 `
          -DockerHubUsername $env:DOCKER_HUB_USERNAME `
          -DockerHubToken $env:DOCKER_HUB_TOKEN `
          -ImageName $env:IMAGE_NAME `
          -ImageTag $env:GITHUB_SHA `
          -MultiPlatform
```

### Azure DevOps
```yaml
# azure-pipelines.yml
trigger:
- main

pool:
  vmImage: 'ubuntu-latest'

variables:
  dockerHubUsername: 'myusername'
  imageName: 'azure-mcp-http-host'

steps:
- task: PowerShell@2
  displayName: 'Build and Push Docker Image'
  inputs:
    filePath: 'servers/Azure.Mcp.Server/HttpHost/Deploy-DockerHub.ps1'
    arguments: '-DockerHubUsername $(dockerHubUsername) -DockerHubToken $(DOCKER_HUB_TOKEN) -ImageName $(imageName) -ImageTag $(Build.BuildNumber) -MultiPlatform'
  env:
    DOCKER_HUB_TOKEN: $(DOCKER_HUB_TOKEN)
```

## Testing the Deployment

```bash
# Test the container is running
curl -I http://localhost:5001

# Expected response: HTTP 406 (Not Acceptable) - this is normal for MCP protocol
# The server expects MCP protocol messages, not HTTP GET requests

# Check container logs
docker logs azure-mcp-host

# Stop and remove container
docker stop azure-mcp-host
docker rm azure-mcp-host
```