#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Setup script for Azure DevOps pipelines and infrastructure

.DESCRIPTION
    This script helps set up the Azure DevOps environment, service connections,
    and backend infrastructure required for the Azure MCP Server CI/CD pipelines.

.PARAMETER Action
    The setup action to perform: backend, validate, or help

.PARAMETER SubscriptionId
    Azure subscription ID for resource creation

.PARAMETER Location
    Azure region for resource deployment (default: East US)

.PARAMETER ResourceGroupName
    Resource group name for Terraform backend (default: rg-terraform-backend)

.PARAMETER StorageAccountName
    Storage account name for Terraform state (must be globally unique)

.PARAMETER ContainerRegistryName
    Azure Container Registry name (must be globally unique)

.EXAMPLE
    .\setup-pipelines.ps1 -Action backend -SubscriptionId "12345678-1234-1234-1234-123456789012"
    .\setup-pipelines.ps1 -Action validate
    .\setup-pipelines.ps1 -Action help

.NOTES
    Prerequisites:
    - Azure CLI installed and authenticated
    - Appropriate Azure permissions (Contributor or Owner)
    - Azure DevOps organization and project created
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("backend", "validate", "help")]
    [string]$Action,
    
    [string]$SubscriptionId,
    [string]$Location = "East US",
    [string]$ResourceGroupName = "rg-terraform-backend",
    [string]$StorageAccountName,
    [string]$ContainerRegistryName
)

$ErrorActionPreference = "Stop"

Write-Host "🚀 Azure MCP Server Pipeline Setup" -ForegroundColor Cyan
Write-Host "Action: $Action" -ForegroundColor Green

# Function to show help information
function Show-Help {
    Write-Host @"

📋 Azure MCP Server Pipeline Setup Guide
========================================

This script helps you set up the required Azure infrastructure and Azure DevOps
configuration for the Azure MCP Server CI/CD pipelines.

🏗️ SETUP STEPS:

1. CREATE BACKEND INFRASTRUCTURE
   Run: .\setup-pipelines.ps1 -Action backend -SubscriptionId "your-sub-id"
   
   This creates:
   - Resource Group for Terraform backend
   - Storage Account for Terraform state
   - Azure Container Registry for images

2. CONFIGURE AZURE DEVOPS
   Manual steps in Azure DevOps:
   
   a) Create Service Connections:
      - Project Settings → Service connections → New service connection
      - Choose "Azure Resource Manager" → Service principal (automatic)
      - Name: azure-container-registry-connection
      - Name: azure-terraform-connection
   
   b) Create Variable Groups:
      - Library → Variable Groups → New variable group
      - Use values from pipeline-variables.template
      - Groups needed:
        * container-registry-config
        * terraform-config
        * environment-config-dev
        * environment-config-staging
        * environment-config-prod
   
   c) Create Environments:
      - Pipelines → Environments → New environment
      - Name: azure-mcp-server-production
      - Add approval gates for production deployments

3. CREATE PIPELINES
   - Pipelines → New pipeline → Azure Repos Git
   - Select repository and YAML files:
     * .azure-pipelines/build-container.yml
     * .azure-pipelines/deploy-infrastructure.yml

4. VALIDATE SETUP
   Run: .\setup-pipelines.ps1 -Action validate
   
   This checks:
   - Azure authentication
   - Required resources existence
   - Permissions validation

🔧 TROUBLESHOOTING:

- Authentication Issues: Run 'az login' and ensure correct subscription
- Permission Errors: Ensure account has Contributor access to subscription
- Naming Conflicts: Storage account and ACR names must be globally unique
- Service Connections: Verify service principal permissions in Azure Portal

📚 MORE INFO:

- Pipeline Documentation: See README.md in .azure-pipelines folder
- Variable Configuration: See pipeline-variables.template
- Azure DevOps Docs: https://docs.microsoft.com/azure/devops/

"@ -ForegroundColor White
}

# Function to validate Azure CLI and authentication
function Test-AzureConnection {
    Write-Host "🔍 Validating Azure connection..." -ForegroundColor Yellow
    
    try {
        $account = az account show | ConvertFrom-Json
        Write-Host "✅ Authenticated as: $($account.user.name)" -ForegroundColor Green
        Write-Host "   Subscription: $($account.name) ($($account.id))" -ForegroundColor Gray
        
        if ($SubscriptionId -and $account.id -ne $SubscriptionId) {
            Write-Host "⚠️ Setting subscription to: $SubscriptionId" -ForegroundColor Yellow
            az account set --subscription $SubscriptionId
        }
        
        return $true
    }
    catch {
        Write-Host "❌ Azure CLI authentication failed. Please run 'az login'" -ForegroundColor Red
        return $false
    }
}

# Function to create Terraform backend infrastructure
function New-TerraformBackend {
    Write-Host "🏗️ Creating Terraform backend infrastructure..." -ForegroundColor Yellow
    
    if (-not $SubscriptionId) {
        Write-Host "❌ SubscriptionId parameter is required for backend creation" -ForegroundColor Red
        return $false
    }
    
    if (-not $StorageAccountName) {
        $StorageAccountName = "tfbackend$(Get-Random -Minimum 1000 -Maximum 9999)"
        Write-Host "📝 Generated storage account name: $StorageAccountName" -ForegroundColor Gray
    }
    
    if (-not $ContainerRegistryName) {
        $ContainerRegistryName = "acrazmcp$(Get-Random -Minimum 1000 -Maximum 9999)"
        Write-Host "📝 Generated container registry name: $ContainerRegistryName" -ForegroundColor Gray
    }
    
    try {
        # Create resource group
        Write-Host "Creating resource group: $ResourceGroupName" -ForegroundColor Gray
        az group create --name $ResourceGroupName --location $Location
        
        # Create storage account for Terraform state
        Write-Host "Creating storage account: $StorageAccountName" -ForegroundColor Gray
        az storage account create `
            --resource-group $ResourceGroupName `
            --name $StorageAccountName `
            --sku Standard_LRS `
            --encryption-services blob `
            --location $Location
        
        # Create storage container for Terraform state
        Write-Host "Creating storage container: tfstate" -ForegroundColor Gray
        az storage container create `
            --name tfstate `
            --account-name $StorageAccountName
        
        # Create Azure Container Registry
        Write-Host "Creating Azure Container Registry: $ContainerRegistryName" -ForegroundColor Gray
        az acr create `
            --resource-group $ResourceGroupName `
            --name $ContainerRegistryName `
            --sku Standard `
            --location $Location `
            --admin-enabled true
        
        Write-Host "✅ Backend infrastructure created successfully!" -ForegroundColor Green
        
        # Display configuration summary
        Write-Host "`n📊 Configuration Summary:" -ForegroundColor Cyan
        Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor White
        Write-Host "Storage Account: $StorageAccountName" -ForegroundColor White
        Write-Host "Container Registry: $ContainerRegistryName.azurecr.io" -ForegroundColor White
        Write-Host "Location: $Location" -ForegroundColor White
        
        # Generate configuration for Azure DevOps
        Write-Host "`n📝 Azure DevOps Variable Group Configuration:" -ForegroundColor Cyan
        Write-Host @"
# Variable Group: terraform-config
TERRAFORM_BACKEND_RG = "$ResourceGroupName"
TERRAFORM_BACKEND_SA = "$StorageAccountName"

# Variable Group: container-registry-config  
AZURE_CONTAINER_REGISTRY = "$ContainerRegistryName.azurecr.io"
"@ -ForegroundColor White
        
        return $true
    }
    catch {
        Write-Host "❌ Failed to create backend infrastructure: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Function to validate existing setup
function Test-Setup {
    Write-Host "🔍 Validating setup..." -ForegroundColor Yellow
    $errors = @()
    
    # Check if backend resource group exists
    try {
        $rg = az group show --name $ResourceGroupName | ConvertFrom-Json
        Write-Host "✅ Resource group '$ResourceGroupName' exists" -ForegroundColor Green
    }
    catch {
        $errors += "Resource group '$ResourceGroupName' not found"
    }
    
    # Check if storage account exists (if provided)
    if ($StorageAccountName) {
        try {
            $sa = az storage account show --name $StorageAccountName --resource-group $ResourceGroupName | ConvertFrom-Json
            Write-Host "✅ Storage account '$StorageAccountName' exists" -ForegroundColor Green
        }
        catch {
            $errors += "Storage account '$StorageAccountName' not found"
        }
    }
    
    # Check if container registry exists (if provided)
    if ($ContainerRegistryName) {
        try {
            $acr = az acr show --name $ContainerRegistryName --resource-group $ResourceGroupName | ConvertFrom-Json
            Write-Host "✅ Container registry '$ContainerRegistryName' exists" -ForegroundColor Green
        }
        catch {
            $errors += "Container registry '$ContainerRegistryName' not found"
        }
    }
    
    if ($errors.Count -eq 0) {
        Write-Host "✅ All validations passed!" -ForegroundColor Green
        return $true
    }
    else {
        Write-Host "❌ Validation errors found:" -ForegroundColor Red
        foreach ($error in $errors) {
            Write-Host "   - $error" -ForegroundColor Red
        }
        return $false
    }
}

# Main execution
try {
    switch ($Action) {
        "help" {
            Show-Help
        }
        "backend" {
            if (-not (Test-AzureConnection)) {
                exit 1
            }
            if (-not (New-TerraformBackend)) {
                exit 1
            }
        }
        "validate" {
            if (-not (Test-AzureConnection)) {
                exit 1
            }
            if (-not (Test-Setup)) {
                exit 1
            }
        }
    }
    
    Write-Host "`n🎉 Operation completed successfully!" -ForegroundColor Green
    
    if ($Action -eq "backend") {
        Write-Host "`n📚 Next Steps:" -ForegroundColor Cyan
        Write-Host "1. Configure Azure DevOps service connections" -ForegroundColor White
        Write-Host "2. Create variable groups using pipeline-variables.template" -ForegroundColor White
        Write-Host "3. Set up environments with approval gates" -ForegroundColor White
        Write-Host "4. Create the CI/CD pipelines" -ForegroundColor White
        Write-Host "`nFor detailed instructions, run: .\setup-pipelines.ps1 -Action help" -ForegroundColor Gray
    }
}
catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}