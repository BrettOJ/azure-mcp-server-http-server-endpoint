# Azure MCP Server Container Instance Deployment

This Terraform configuration deploys the Azure MCP (Model Context Protocol) Server as a container instance in Azure using Azure Verified Modules (AVM). The deployment follows Azure and Terraform best practices for security, maintainability, and scalability.

## Architecture Overview

The deployment creates the following Azure resources:

- **Resource Group**: Container for all related resources
- **Container Instance**: Hosts the Azure MCP Server container
- **User Managed Identity**: Provides secure authentication for Azure services
- **Log Analytics Workspace**: Enables monitoring and logging
- **Role Assignments**: Grants necessary permissions to the managed identity

## Prerequisites

1. **Terraform**: Version 1.9.0 or higher
   ```bash
   winget install Hashicorp.Terraform
   ```

2. **Azure CLI**: For authentication and resource management
   ```bash
   winget install Microsoft.AzureCLI
   ```

3. **Azure Subscription**: Active subscription with appropriate permissions

## Quick Start

### 1. Authenticate with Azure

```bash
# Login to Azure
az login

# Set your subscription (optional)
az account set --subscription "your-subscription-id"
```

### 2. Configure Variables

Copy and customize the example variables file:

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` to match your requirements:

```hcl
location     = "East US"
environment  = "dev"
container_cpu    = 1.0
container_memory = 2.0
```

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Preview changes
terraform plan

# Deploy resources
terraform apply -auto-approve
```

### 4. Access Your MCP Server

After deployment, Terraform will output the container URL:

```bash
# Get the container URL
terraform output container_url
```

## Configuration Options

### Container Settings

| Variable | Description | Default | Range |
|----------|-------------|---------|-------|
| `container_image` | Docker image for MCP Server | `ghcr.io/microsoft/azure-mcp-server:latest` | Any valid image |
| `container_cpu` | CPU allocation (cores) | `1.0` | 0.1 - 4.0 |
| `container_memory` | Memory allocation (GB) | `2.0` | 0.5 - 16.0 |

### Security Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_contributor_access` | Grant Contributor access to resource group | `true` |
| `enable_subscription_reader` | Grant Reader access to subscription | `true` |
| `secure_environment_variables` | Encrypted environment variables | `{}` |

### Environment Variables

The container is automatically configured with:

- `AZURE_CLIENT_ID`: Managed identity client ID
- `AZURE_TENANT_ID`: Azure tenant ID
- `ASPNETCORE_ENVIRONMENT`: Environment setting
- `ASPNETCORE_URLS`: HTTP listener configuration

## Monitoring and Logging

The deployment includes:

- **Log Analytics Workspace**: Centralized logging
- **Container Insights**: Performance monitoring
- **Health Probes**: Liveness and readiness checks

Access logs through:
- Azure Portal → Log Analytics Workspace
- Container Instance → Logs
- Azure Monitor

## Security Features

### Managed Identity
- No stored credentials in container
- Azure-native authentication
- Automatic credential rotation

### Network Security
- Public IP with controlled access
- Health endpoint monitoring
- Secure environment variable storage

### RBAC Permissions
- Least privilege access model
- Scoped role assignments
- Audit trail for access

## Customization Examples

### Custom Environment Variables

```hcl
# In terraform.tfvars
secure_environment_variables = {
  "CUSTOM_API_KEY" = "your-secure-key"
  "LOG_LEVEL"      = "Debug"
}
```

### Production Configuration

```hcl
# In terraform.tfvars
environment      = "prod"
container_cpu    = 2.0
container_memory = 4.0
location         = "West US 2"

tags = {
  Environment = "Production"
  CostCenter  = "Engineering"
  Owner       = "Platform-Team"
}
```

### Development Configuration

```hcl
# In terraform.tfvars
environment                = "dev"
container_cpu             = 0.5
container_memory          = 1.0
enable_contributor_access = true
```

## Maintenance and Operations

### Updates

```bash
# Update container image
terraform apply -var="container_image=ghcr.io/microsoft/azure-mcp-server:v2.0.0"

# Scale resources
terraform apply -var="container_cpu=2.0" -var="container_memory=4.0"
```

### Monitoring

```bash
# View container logs
az container logs --resource-group <rg-name> --name <container-name>

# Check container status
az container show --resource-group <rg-name> --name <container-name> --query instanceView.state
```

### Troubleshooting

Common issues and solutions:

1. **Container won't start**
   - Check environment variables
   - Verify image availability
   - Review container logs

2. **Authentication failures**
   - Confirm managed identity permissions
   - Check role assignments
   - Verify Azure CLI authentication

3. **Network connectivity**
   - Confirm public IP assignment
   - Check DNS name label
   - Verify port configuration

## Cleanup

To remove all resources:

```bash
terraform destroy -auto-approve
```

## Outputs

After successful deployment, the following information is available:

| Output | Description |
|--------|-------------|
| `container_url` | Full URL to access the MCP Server |
| `container_public_ip` | Public IP address |
| `container_fqdn` | Fully qualified domain name |
| `resource_group_name` | Created resource group |
| `managed_identity_client_id` | Managed identity client ID |

## Cost Optimization

- Use appropriate container sizing for your workload
- Consider Azure Container Apps for production workloads
- Monitor resource usage through Azure Cost Management
- Use resource tags for cost allocation

## Support

For issues and questions:

1. Check the [Azure MCP Server documentation](https://learn.microsoft.com/azure/developer/azure-mcp-server/)
2. Review container logs for error messages
3. Consult the [troubleshooting guide](https://github.com/microsoft/mcp/blob/main/servers/Azure.Mcp.Server/TROUBLESHOOTING.md)
4. Open an issue in the [GitHub repository](https://github.com/microsoft/mcp)

## Azure Portal Links

After deployment, access your resources:

- Resource Group: `https://portal.azure.com/#@<tenant>/resource/subscriptions/<subscription>/resourceGroups/<rg-name>`
- Container Instance: `https://portal.azure.com/#@<tenant>/resource/subscriptions/<subscription>/resourceGroups/<rg-name>/providers/Microsoft.ContainerInstance/containerGroups/<container-name>`
- Log Analytics: `https://portal.azure.com/#@<tenant>/resource/subscriptions/<subscription>/resourceGroups/<rg-name>/providers/Microsoft.OperationalInsights/workspaces/<workspace-name>`