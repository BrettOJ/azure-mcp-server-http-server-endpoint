#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Deploy Azure MCP Server to Azure Container Instances using Terraform

.DESCRIPTION
    This script automates the deployment of the Azure MCP Server container to Azure Container Instances
    using Terraform with Azure Verified Modules. It follows Azure deployment best practices.

.PARAMETER Action
    The action to perform: init, plan, apply, destroy, or validate

.PARAMETER AutoApprove
    Skip interactive approval for apply and destroy operations

.PARAMETER VarFile
    Path to terraform.tfvars file (defaults to terraform.tfvars)

.EXAMPLE
    .\deploy.ps1 -Action init
    .\deploy.ps1 -Action plan
    .\deploy.ps1 -Action apply -AutoApprove
    .\deploy.ps1 -Action destroy -AutoApprove

.NOTES
    Prerequisites:
    - Terraform 1.9.0 or higher
    - Azure CLI
    - Authenticated Azure session (az login)
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("init", "plan", "apply", "destroy", "validate", "output")]
    [string]$Action,
    
    [switch]$AutoApprove,
    
    [string]$VarFile = "terraform.tfvars"
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Get script directory
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "🚀 Azure MCP Server Deployment Script" -ForegroundColor Cyan
Write-Host "Action: $Action" -ForegroundColor Green

# Check prerequisites
function Test-Prerequisites {
    Write-Host "📋 Checking prerequisites..." -ForegroundColor Yellow
    
    # Check Terraform installation
    try {
        $tfVersion = terraform version -json | ConvertFrom-Json
        Write-Host "✅ Terraform $($tfVersion.terraform_version) found" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Terraform not found. Please install Terraform:" -ForegroundColor Red
        Write-Host "   winget install Hashicorp.Terraform" -ForegroundColor White
        exit 1
    }
    
    # Check Azure CLI installation
    try {
        $azVersion = az version | ConvertFrom-Json
        Write-Host "✅ Azure CLI $($azVersion.'azure-cli') found" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Azure CLI not found. Please install Azure CLI:" -ForegroundColor Red
        Write-Host "   winget install Microsoft.AzureCLI" -ForegroundColor White
        exit 1
    }
    
    # Check Azure authentication
    try {
        $account = az account show | ConvertFrom-Json
        Write-Host "✅ Authenticated as $($account.user.name)" -ForegroundColor Green
        Write-Host "   Subscription: $($account.name) ($($account.id))" -ForegroundColor Gray
    }
    catch {
        Write-Host "❌ Not authenticated with Azure. Please run:" -ForegroundColor Red
        Write-Host "   az login" -ForegroundColor White
        exit 1
    }
}

# Initialize Terraform
function Invoke-TerraformInit {
    Write-Host "🔧 Initializing Terraform..." -ForegroundColor Yellow
    terraform init
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Terraform init failed" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ Terraform initialized successfully" -ForegroundColor Green
}

# Validate Terraform configuration
function Invoke-TerraformValidate {
    Write-Host "🔍 Validating Terraform configuration..." -ForegroundColor Yellow
    terraform validate
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Terraform validation failed" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ Terraform configuration is valid" -ForegroundColor Green
}

# Plan Terraform deployment
function Invoke-TerraformPlan {
    Write-Host "📊 Creating Terraform plan..." -ForegroundColor Yellow
    
    $planArgs = @()
    if (Test-Path $VarFile) {
        $planArgs += "-var-file=$VarFile"
        Write-Host "📝 Using variables file: $VarFile" -ForegroundColor Gray
    }
    
    terraform plan @planArgs
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Terraform plan failed" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ Terraform plan completed" -ForegroundColor Green
}

# Apply Terraform configuration
function Invoke-TerraformApply {
    Write-Host "🚀 Applying Terraform configuration..." -ForegroundColor Yellow
    
    $applyArgs = @()
    if (Test-Path $VarFile) {
        $applyArgs += "-var-file=$VarFile"
    }
    if ($AutoApprove) {
        $applyArgs += "-auto-approve"
    }
    
    terraform apply @applyArgs
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Terraform apply failed" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ Deployment completed successfully!" -ForegroundColor Green
    
    # Show important outputs
    Write-Host "`n📊 Deployment Summary:" -ForegroundColor Cyan
    terraform output deployment_summary
    
    Write-Host "`n🌐 Access your Azure MCP Server at:" -ForegroundColor Cyan
    terraform output container_url
    
    # Provide Azure Portal link
    $rgName = terraform output -raw resource_group_name
    $subscriptionId = (az account show | ConvertFrom-Json).id
    $portalUrl = "https://portal.azure.com/#@/resource/subscriptions/$subscriptionId/resourceGroups/$rgName"
    
    Write-Host "`n🔗 Azure Portal:" -ForegroundColor Cyan
    Write-Host $portalUrl -ForegroundColor Blue
}

# Destroy Terraform resources
function Invoke-TerraformDestroy {
    Write-Host "💥 Destroying Terraform resources..." -ForegroundColor Yellow
    
    $destroyArgs = @()
    if (Test-Path $VarFile) {
        $destroyArgs += "-var-file=$VarFile"
    }
    if ($AutoApprove) {
        $destroyArgs += "-auto-approve"
    }
    
    terraform destroy @destroyArgs
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Terraform destroy failed" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✅ Resources destroyed successfully" -ForegroundColor Green
}

# Show Terraform outputs
function Show-TerraformOutput {
    Write-Host "📊 Terraform Outputs:" -ForegroundColor Cyan
    terraform output
}

# Main execution
try {
    Test-Prerequisites
    
    switch ($Action) {
        "init" {
            Invoke-TerraformInit
        }
        "validate" {
            Invoke-TerraformValidate
        }
        "plan" {
            Invoke-TerraformInit
            Invoke-TerraformValidate
            Invoke-TerraformPlan
        }
        "apply" {
            Invoke-TerraformInit
            Invoke-TerraformValidate
            Invoke-TerraformApply
        }
        "destroy" {
            Invoke-TerraformDestroy
        }
        "output" {
            Show-TerraformOutput
        }
    }
    
    Write-Host "`n🎉 Operation completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}