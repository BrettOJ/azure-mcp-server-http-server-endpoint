#!/usr/bin/env pwsh
param(
    [Parameter(Mandatory)]
    [string]$AcrName,
    
    [Parameter(Mandatory)]
    [string]$ResourceGroup,
    
    [string]$ContainerName = "azure-mcp-http-host",
    
    [string]$ImageTag = "latest",
    
    [string]$Location = "East US",
    
    [int]$Port = 5001,
    
    [string]$DnsNameLabel,
    
    [string]$SubscriptionId,
    
    [double]$CpuCores = 1.0,
    
    [double]$MemoryGb = 1.5
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "🚀 Deploying Azure MCP HTTP Host to Azure Container Instances" -ForegroundColor Green

# Set subscription if provided
if ($SubscriptionId) {
    Write-Host "Setting subscription to $SubscriptionId" -ForegroundColor Yellow
    az account set --subscription $SubscriptionId
}

# Get current subscription for reference
$currentSub = az account show --query "name" -o tsv
Write-Host "Using subscription: $currentSub" -ForegroundColor Cyan

# Generate DNS name label if not provided
if (-not $DnsNameLabel) {
    $DnsNameLabel = "$ContainerName-$(Get-Random -Minimum 1000 -Maximum 9999)"
}

# Construct image URL
$imageUrl = "$AcrName.azurecr.io/azure-mcp-http-host:$ImageTag"

Write-Host "Configuration:" -ForegroundColor Cyan
Write-Host "  Resource Group: $ResourceGroup" -ForegroundColor White
Write-Host "  Container Name: $ContainerName" -ForegroundColor White
Write-Host "  Image: $imageUrl" -ForegroundColor White
Write-Host "  Location: $Location" -ForegroundColor White
Write-Host "  CPU Cores: $CpuCores" -ForegroundColor White
Write-Host "  Memory: ${MemoryGb} GB" -ForegroundColor White
Write-Host "  Port: $Port" -ForegroundColor White
Write-Host "  DNS Label: $DnsNameLabel" -ForegroundColor White

# Create resource group if it doesn't exist
Write-Host "Ensuring resource group exists..." -ForegroundColor Yellow
az group create --name $ResourceGroup --location $Location --output none

# Get ACR credentials
Write-Host "Getting ACR credentials..." -ForegroundColor Yellow
$acrServer = az acr show --name $AcrName --query "loginServer" -o tsv
$acrUsername = az acr credential show --name $AcrName --query "username" -o tsv
$acrPassword = az acr credential show --name $AcrName --query "passwords[0].value" -o tsv

if (-not $acrServer -or -not $acrUsername -or -not $acrPassword) {
    throw "Failed to get ACR credentials"
}

# Deploy to Azure Container Instances
Write-Host "Deploying to Azure Container Instances..." -ForegroundColor Yellow

$deployCommand = @"
az container create \
    --resource-group $ResourceGroup \
    --name $ContainerName \
    --image $imageUrl \
    --registry-login-server $acrServer \
    --registry-username $acrUsername \
    --registry-password $acrPassword \
    --dns-name-label $DnsNameLabel \
    --ports $Port \
    --protocol TCP \
    --cpu $CpuCores \
    --memory $MemoryGb \
    --restart-policy Always \
    --environment-variables ASPNETCORE_URLS=http://0.0.0.0:$Port ASPNETCORE_ENVIRONMENT=Production \
    --output table
"@

Invoke-Expression $deployCommand

if ($LASTEXITCODE -ne 0) {
    throw "Container deployment failed"
}

# Get the container details
Write-Host "Getting container details..." -ForegroundColor Yellow
$containerDetails = az container show --resource-group $ResourceGroup --name $ContainerName --query "{fqdn:ipAddress.fqdn,ip:ipAddress.ip,state:containers[0].instanceView.currentState.state}" -o json | ConvertFrom-Json

Write-Host "✅ Container deployed successfully!" -ForegroundColor Green
Write-Host "Container Details:" -ForegroundColor Cyan
Write-Host "  Name: $ContainerName" -ForegroundColor White
Write-Host "  State: $($containerDetails.state)" -ForegroundColor White
Write-Host "  Public IP: $($containerDetails.ip)" -ForegroundColor White
Write-Host "  FQDN: $($containerDetails.fqdn)" -ForegroundColor White
Write-Host "  MCP HTTP Endpoint: http://$($containerDetails.fqdn):$Port" -ForegroundColor Green

Write-Host "`n🎉 Deployment completed successfully!" -ForegroundColor Green
Write-Host "Your Azure MCP HTTP Host is now available at: http://$($containerDetails.fqdn):$Port" -ForegroundColor Yellow

# Show logs command for troubleshooting
Write-Host "`nTo view logs, run:" -ForegroundColor Cyan
Write-Host "az container logs --resource-group $ResourceGroup --name $ContainerName --follow" -ForegroundColor White

# Show delete command for cleanup
Write-Host "`nTo delete the container, run:" -ForegroundColor Cyan
Write-Host "az container delete --resource-group $ResourceGroup --name $ContainerName --yes" -ForegroundColor White