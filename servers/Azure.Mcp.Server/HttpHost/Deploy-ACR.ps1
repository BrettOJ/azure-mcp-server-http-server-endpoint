#!/usr/bin/env pwsh
param(
    [Parameter(Mandatory)]
    [string]$DockerHubUsername,
    
    [string]$ImageName = "azure-mcp-http-host",
    
    [string]$ImageTag = "latest",
    
    [string]$DockerHubToken,
    
    [switch]$BuildOnly
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "🚀 Building and deploying Azure MCP HTTP Host to Docker Hub" -ForegroundColor Green

# Validate Docker is running
$dockerVersion = docker version --format '{{.Server.Version}}' 2>$null
if (-not $dockerVersion) {
    Write-Error "Docker is not running or not installed. Please start Docker Desktop."
}

Write-Host "Using Docker version: $dockerVersion" -ForegroundColor Cyan

# Ensure we're in the correct directory (mcp repo root)
$repoRoot = git rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    Write-Error "Not in a git repository. Please run from the mcp repository root."
}

Push-Location $repoRoot
try {
    # Build the Docker image
    $imageName = "$DockerHubUsername/$ImageName"
    $fullImageName = "${imageName}:${ImageTag}"
    
    Write-Host "Building Docker image: $fullImageName" -ForegroundColor Yellow
    
    docker build -f servers/Azure.Mcp.Server/HttpHost/Dockerfile -t $fullImageName .
    
    if ($LASTEXITCODE -ne 0) {
        throw "Docker build failed"
    }
    
    Write-Host "✅ Docker image built successfully" -ForegroundColor Green
    
    if ($BuildOnly) {
        Write-Host "Build-only mode. Skipping Docker Hub push." -ForegroundColor Yellow
        Write-Host "Local image created: $fullImageName" -ForegroundColor Cyan
        return
    }
    
    # Login to Docker Hub
    Write-Host "Logging into Docker Hub as: $DockerHubUsername" -ForegroundColor Yellow
    
    if ($DockerHubToken) {
        # Use token authentication (recommended for CI/CD)
        Write-Host "Using access token for authentication" -ForegroundColor Cyan
        Write-Output $DockerHubToken | docker login docker.io --username $DockerHubUsername --password-stdin
    } else {
        # Interactive login
        Write-Host "Please enter your Docker Hub password when prompted" -ForegroundColor Cyan
        docker login docker.io --username $DockerHubUsername
    }
    
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Hub login failed"
    }
    
    # Push the image
    Write-Host "Pushing image to Docker Hub..." -ForegroundColor Yellow
    docker push $fullImageName
    
    if ($LASTEXITCODE -ne 0) {
        throw "Docker push failed"
    }
    
    Write-Host "✅ Image pushed successfully to Docker Hub" -ForegroundColor Green
    Write-Host "Image URL: docker.io/$fullImageName" -ForegroundColor Cyan
    Write-Host "Docker Hub URL: https://hub.docker.com/r/$imageName" -ForegroundColor Cyan
    
} finally {
    Pop-Location
}

Write-Host "🎉 Deployment completed successfully!" -ForegroundColor Green
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Run locally: docker run -p 5001:5001 $fullImageName" -ForegroundColor White
Write-Host "2. Deploy to cloud platforms using: docker.io/$fullImageName" -ForegroundColor White
Write-Host "3. Use docker-compose with the published image" -ForegroundColor White