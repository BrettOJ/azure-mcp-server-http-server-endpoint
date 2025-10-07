# Azure MCP HTTP Host - Container Deployment

This directory contains the containerized version of the Azure MCP HTTP Host, which provides an HTTP-to-stdio bridge for the Azure MCP Server.

## 🚀 Quick Deployment Options

### Option 1: Deploy to Docker Hub

#### Prerequisites

- [Docker](https://www.docker.com/get-started) installed and running
- Docker Hub account
- PowerShell 7+ (for deployment scripts)

#### Build and Push to Docker Hub

```powershell
# Build and push to Docker Hub
./Deploy-DockerHub.ps1 -DockerHubUsername "yourusername"

# With custom image name and tag
./Deploy-DockerHub.ps1 -DockerHubUsername "yourusername" -ImageName "my-mcp-host" -ImageTag "v1.0"

# Multi-platform build (amd64 + arm64)
./Deploy-DockerHub.ps1 -DockerHubUsername "yourusername" -MultiPlatform

# Using access token (recommended for CI/CD)
./Deploy-DockerHub.ps1 -DockerHubUsername "yourusername" -DockerHubToken $env:DOCKER_HUB_TOKEN
```

#### Run from Docker Hub

```bash
# Run the published image
docker run -p 5001:5001 yourusername/azure-mcp-http-host:latest
```

### Option 2: Deploy to Azure

#### Azure Prerequisites

- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) installed and logged in
- [Docker](https://www.docker.com/get-started) installed
- PowerShell 7+ (for deployment scripts)

#### Build and Push to Azure Container Registry (ACR)

```powershell
# Create ACR if needed
az acr create --name myazmcpacr --resource-group my-resource-group --sku Basic --admin-enabled

# Build and push to ACR
./Deploy-ACR.ps1 -DockerHubUsername "yourusername" -ImageName "azure-mcp-http-host"
```

#### Deploy to Azure Container Instances (ACI)

```powershell
# Deploy to ACI
./Deploy-ACI.ps1 -AcrName "myazmcpacr" -ResourceGroup "my-resource-group"
```

Your Azure MCP HTTP Host will be available at: `http://<dns-name>.eastus.azurecontainer.io:5001`

## 🐳 Local Development with Docker

### Build locally

```bash
# From the repository root
docker build -f servers/Azure.Mcp.Server/HttpHost/Dockerfile -t azure-mcp-http-host .
```

### Run locally

```bash
# Run the container
docker run -p 5001:5001 azure-mcp-http-host

# Or use Docker Compose
cd servers/Azure.Mcp.Server/HttpHost
docker-compose up
```

Access the server at: `http://localhost:5001`

## ⚙️ Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ASPNETCORE_URLS` | `http://0.0.0.0:5001` | The URLs the server binds to |
| `ASPNETCORE_ENVIRONMENT` | `Production` | The hosting environment |

### Container Specifications

- **Base Image**: `mcr.microsoft.com/dotnet/aspnet:9.0`
- **Exposed Port**: 5001
- **Default CPU**: 1.0 cores
- **Default Memory**: 1.5 GB
- **Health Check**: HTTP GET to `/`

## 🔧 Advanced Deployment Options

### Custom Port

```powershell
./Deploy-ACI.ps1 -AcrName "myacr" -ResourceGroup "my-rg" -Port 8080
```

### Custom DNS Name

```powershell
./Deploy-ACI.ps1 -AcrName "myacr" -ResourceGroup "my-rg" -DnsNameLabel "my-mcp-server"
```

### Different Region

```powershell
./Deploy-ACI.ps1 -AcrName "myacr" -ResourceGroup "my-rg" -Location "West US 2"
```

### Resource Scaling

```powershell
./Deploy-ACI.ps1 -AcrName "myacr" -ResourceGroup "my-rg" -CpuCores 2.0 -MemoryGb 4.0
```

## 📊 Monitoring and Troubleshooting

### View Container Logs

```bash
az container logs --resource-group my-resource-group --name azure-mcp-http-host --follow
```

### Check Container Status

```bash
az container show --resource-group my-resource-group --name azure-mcp-http-host --query "containers[0].instanceView.currentState"
```

### Health Check Endpoint

The container includes a health check that can be accessed at:

- Local: `http://localhost:5001/`
- Azure: `http://<your-fqdn>:5001/`

### Expected Responses

- **Healthy**: HTTP 406 (Not Acceptable) - This is normal! The server expects MCP protocol messages
- **Unhealthy**: No response or connection refused

## 🔒 Security Considerations

- The container runs as a non-root user (uid: 1001)
- CORS is enabled for all origins (suitable for development/testing)
- For production use, consider:
  - Using HTTPS with proper certificates
  - Restricting CORS to specific origins
  - Implementing authentication/authorization
  - Using Azure Container Apps with managed identity

## 🚀 Azure Container Apps Alternative

For production workloads, consider Azure Container Apps:

```bash
# Create Container Apps environment
az containerapp env create --name my-mcp-env --resource-group my-resource-group --location eastus

# Deploy to Container Apps
az containerapp create \
  --name azure-mcp-http-host \
  --resource-group my-resource-group \
  --environment my-mcp-env \
  --image myazmcpacr.azurecr.io/azure-mcp-http-host:latest \
  --registry-server myazmcpacr.azurecr.io \
  --target-port 5001 \
  --ingress external \
  --min-replicas 1 \
  --max-replicas 3
```

## 📋 Troubleshooting

### Build Issues

1. **Build fails**: Ensure you're running from the repository root
2. **Missing dependencies**: Check that all project references are correct
3. **Docker build timeout**: Increase Docker build timeout or use faster internet

### Deployment Issues

1. **ACR login fails**: Ensure you have contributor access to the ACR
2. **Container won't start**: Check logs for startup errors
3. **Port conflicts**: Use a different port with `-Port` parameter

### Runtime Issues

1. **406 responses are normal** - The server expects MCP protocol messages
2. **Connection refused**: Check if container is running and port is correct
3. **Authentication errors**: Ensure Azure authentication is properly configured

## 🔄 Updates and Maintenance

### Update the container

```powershell
# Build and push new version
./Deploy-ACR.ps1 -AcrName "myacr" -ResourceGroup "my-rg" -ImageTag "v2.0"

# Update ACI with new version
./Deploy-ACI.ps1 -AcrName "myacr" -ResourceGroup "my-rg" -ImageTag "v2.0"
```

### Cleanup

```bash
# Delete the container instance
az container delete --resource-group my-resource-group --name azure-mcp-http-host --yes

# Delete the resource group (removes everything)
az group delete --name my-resource-group --yes
```
