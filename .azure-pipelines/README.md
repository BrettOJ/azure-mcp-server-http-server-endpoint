# Azure DevOps Pipelines for Azure MCP Server

This directory contains Azure DevOps YAML pipelines for building, testing, and deploying the Azure MCP Server container application using CI/CD best practices.

## 🏗️ Pipeline Overview

### 1. Container Build Pipeline (`build-container.yml`)
Builds the .NET application, creates Docker container images, and pushes to Azure Container Registry.

**Triggers:**
- Main/develop branch pushes
- Pull requests to main/develop
- Changes to application code, Dockerfile, or solution files

**Stages:**
1. **Build & Test** - Compiles .NET application, runs unit tests, publishes artifacts
2. **Security Scan** - Scans dependencies for vulnerabilities
3. **Container Build** - Builds and pushes Docker images to ACR
4. **Release Notes** - Generates deployment documentation

### 2. Infrastructure Deployment Pipeline (`deploy-infrastructure.yml`)
Deploys Azure infrastructure using Terraform with the configuration from `.terraform` folder.

**Triggers:**
- Changes to `.terraform/*` files
- Manual execution

**Stages:**
1. **Validation** - Terraform format, validate, security scan
2. **Planning** - Generate and review Terraform execution plan
3. **Approval Gate** - Manual approval for production deployments
4. **Apply** - Deploy infrastructure and validate deployment

## 🚀 Quick Start

### Prerequisites
- Azure DevOps organization and project
- Azure subscription with appropriate permissions
- Azure CLI installed locally

### 1. Setup Backend Infrastructure

```powershell
# Navigate to pipeline directory
cd .azure-pipelines

# Create Terraform backend and ACR
.\setup-pipelines.ps1 -Action backend -SubscriptionId "your-subscription-id"

# Validate setup
.\setup-pipelines.ps1 -Action validate
```

### 2. Configure Azure DevOps

#### Service Connections
Create Azure Resource Manager service connections:

1. **azure-container-registry-connection**
   - Scope: Resource Group or Subscription
   - Used for: Container image builds and ACR operations

2. **azure-terraform-connection**
   - Scope: Subscription
   - Used for: Terraform deployments

#### Variable Groups
Create variable groups using `pipeline-variables.template`:

- `container-registry-config` - ACR and container settings
- `terraform-config` - Terraform backend configuration
- `environment-config-dev` - Development environment variables
- `environment-config-staging` - Staging environment variables  
- `environment-config-prod` - Production environment variables

#### Environments
Create environments for deployment approvals:

- `azure-mcp-server-production` - With manual approval gates
- `azure-mcp-server-staging` (optional) - For staging deployments

### 3. Create Pipelines

1. Go to **Pipelines** → **New pipeline**
2. Select **Azure Repos Git**
3. Choose your repository
4. Select **Existing Azure Pipelines YAML file**
5. Choose pipeline file:
   - `.azure-pipelines/build-container.yml`
   - `.azure-pipelines/deploy-infrastructure.yml`

## 📊 Pipeline Configuration

### Container Build Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `AZURE_CONTAINER_REGISTRY` | ACR hostname | `myacr.azurecr.io` |
| `ACR_SERVICE_CONNECTION` | Service connection name | `azure-container-registry-connection` |
| `buildConfiguration` | .NET build configuration | `Release` |
| `dotnetVersion` | .NET SDK version | `10.x` |

### Infrastructure Deployment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `AZURE_SERVICE_CONNECTION` | Service connection name | `azure-terraform-connection` |
| `TERRAFORM_BACKEND_RG` | Backend resource group | `rg-terraform-backend` |
| `TERRAFORM_BACKEND_SA` | Backend storage account | `tfbackendsa1234` |
| `LOCATION` | Azure region | `East US` |
| `ENVIRONMENT` | Environment name | `dev`, `staging`, `prod` |

### Environment-Specific Configuration

Create separate variable groups for each environment:

```yaml
# Development
ENVIRONMENT: "dev"
CONTAINER_CPU: 1.0
CONTAINER_MEMORY: 2.0
ENABLE_CONTRIBUTOR_ACCESS: true

# Staging  
ENVIRONMENT: "staging"
CONTAINER_CPU: 1.5
CONTAINER_MEMORY: 3.0
ENABLE_CONTRIBUTOR_ACCESS: true

# Production
ENVIRONMENT: "prod" 
CONTAINER_CPU: 2.0
CONTAINER_MEMORY: 4.0
ENABLE_CONTRIBUTOR_ACCESS: false
```

## 🔒 Security Features

### Container Build Security
- **Dependency Scanning** - Checks NuGet packages for vulnerabilities
- **Container Scanning** - Scans Docker images for security issues
- **Code Coverage** - Tracks test coverage metrics
- **Signed Images** - Container images tagged with build metadata

### Infrastructure Security  
- **Terraform Validation** - Format checking and configuration validation
- **Security Scanning** - Checkov scans for infrastructure misconfigurations
- **State Management** - Secure Terraform state in Azure Storage
- **Approval Gates** - Manual approval required for production deployments

### Best Practices Implemented
- ✅ **No hardcoded secrets** - All credentials via service connections
- ✅ **Least privilege access** - Minimal required permissions
- ✅ **Immutable infrastructure** - Terraform-managed resources
- ✅ **Audit trail** - Full deployment history and approvals
- ✅ **Rollback capability** - Versioned container images and state

## 🏃 Running Pipelines

### Container Build Pipeline

**Automatic Triggers:**
```bash
# Pushes to main/develop trigger full pipeline
git push origin main

# Pull requests trigger build and test only
git checkout -b feature/my-feature
git push origin feature/my-feature
# Create PR to main
```

**Manual Execution:**
1. Go to **Pipelines** → Select `build-container`
2. Click **Run pipeline**
3. Choose branch and variables
4. Click **Run**

### Infrastructure Deployment Pipeline

**Automatic Triggers:**
```bash
# Changes to Terraform files trigger pipeline
git add .terraform/
git commit -m "Update infrastructure"
git push origin main
```

**Manual Execution:**
1. Go to **Pipelines** → Select `deploy-infrastructure`  
2. Click **Run pipeline**
3. Select environment variable group
4. Click **Run**

## 📈 Pipeline Outputs

### Container Build Artifacts
- **azure-mcp-server** - Published .NET application
- **container-image** - Image manifest and metadata
- **release-notes** - Deployment documentation

### Infrastructure Deployment Artifacts
- **terraform-plan** - Terraform execution plan
- **deployment-results** - Terraform outputs and validation
- **deployment-summary** - Human-readable deployment report

### Key Outputs
```json
{
  "container_url": "http://azmcp-abc123.eastus.azurecontainer.io:8080",
  "resource_group_name": "rg-azmcp-abc123",
  "managed_identity_client_id": "12345678-1234-1234-1234-123456789012"
}
```

## 🔧 Troubleshooting

### Common Issues

#### 1. Authentication Failures
```
Error: Azure CLI authentication failed
```
**Solution:** Verify service connection configuration and permissions

#### 2. Terraform Backend Issues
```
Error: Backend configuration not found
```
**Solution:** Ensure backend storage account exists and permissions are correct

#### 3. Container Build Failures
```
Error: Docker build failed
```
**Solution:** Check Dockerfile and build context, verify base image availability

#### 4. Resource Naming Conflicts
```
Error: Storage account name already exists
```
**Solution:** Use globally unique names for storage accounts and container registries

### Debugging Steps

1. **Check pipeline logs** - Review detailed execution logs in Azure DevOps
2. **Validate permissions** - Ensure service principals have required access
3. **Test locally** - Run Terraform/Docker commands locally to isolate issues
4. **Review variable groups** - Verify all required variables are set correctly

### Pipeline Logs Location
- **Azure DevOps** → **Pipelines** → **[Pipeline Name]** → **[Run]** → **[Job]** → **Logs**

## 🔄 Pipeline Maintenance

### Regular Tasks

#### Monthly
- Review and update base container images
- Update Terraform provider versions
- Review security scan results
- Rotate service principal credentials

#### Quarterly  
- Update pipeline YAML to latest best practices
- Review and update variable group configurations
- Audit pipeline permissions and service connections
- Performance optimization review

### Version Updates

#### .NET SDK Updates
1. Update `dotnetVersion` variable in `build-container.yml`
2. Test builds in development environment
3. Update Dockerfile base image if needed

#### Terraform Updates
1. Update `terraformVersion` variable in `deploy-infrastructure.yml`
2. Test Terraform operations in development
3. Update provider version constraints if needed

## 📚 Additional Resources

### Documentation Links
- [Azure DevOps Pipelines](https://docs.microsoft.com/azure/devops/pipelines/)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Container Instances](https://docs.microsoft.com/azure/container-instances/)
- [Azure Container Registry](https://docs.microsoft.com/azure/container-registry/)

### Pipeline Templates
- `build-container.yml` - Container build and push pipeline
- `deploy-infrastructure.yml` - Terraform deployment pipeline
- `pipeline-variables.template` - Variable configuration template
- `setup-pipelines.ps1` - Environment setup automation

### Support
For issues and questions:
1. Review pipeline documentation and logs
2. Check Azure DevOps service health
3. Consult Azure MCP Server troubleshooting guide
4. Open issue in repository with pipeline run details

---

**Last Updated:** October 2025  
**Pipeline Version:** 1.0  
**Terraform Version:** 1.9.7  
**.NET Version:** 10.x