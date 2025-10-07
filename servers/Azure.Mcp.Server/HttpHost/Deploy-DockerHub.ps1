#!/usr/bin/env pwsh
param(
    [string]$DockerHubUsername = "bojewell",
    
    [string]$ImageName = "azure-mcp-http-host",
    
    [string]$ImageTag = "latest",
    
    [string]$DockerHubToken,
    
    [switch]$BuildOnly,
    
    [switch]$MultiPlatform
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

# Check for buildx if multi-platform build is requested
if ($MultiPlatform) {
    $buildxVersion = docker buildx version 2>$null
    if (-not $buildxVersion) {
        Write-Error "Docker Buildx is required for multi-platform builds but not available."
    }
    Write-Host "Using Docker Buildx for multi-platform build" -ForegroundColor Cyan
}

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
    
    if ($MultiPlatform) {
        # Multi-platform build (linux/amd64, linux/arm64)
        Write-Host "Building for multiple platforms: linux/amd64,linux/arm64" -ForegroundColor Cyan
        docker buildx create --name mcp-builder --use --bootstrap 2>$null
        
        if ($BuildOnly) {
            docker buildx build --platform linux/amd64,linux/arm64 -f servers/Azure.Mcp.Server/HttpHost/Dockerfile -t $fullImageName .
        } else {
            docker buildx build --platform linux/amd64,linux/arm64 -f servers/Azure.Mcp.Server/HttpHost/Dockerfile -t $fullImageName --push .
        }
    } else {
        # Single platform build (current architecture)
        docker build -f servers/Azure.Mcp.Server/HttpHost/Dockerfile -t $fullImageName .
    }
    
    if ($LASTEXITCODE -ne 0) {
        throw "Docker build failed"
    }
    
    Write-Host "✅ Docker image built successfully" -ForegroundColor Green
    
    if ($BuildOnly) {
        Write-Host "Build-only mode. Skipping Docker Hub push." -ForegroundColor Yellow
        Write-Host "Local image created: $fullImageName" -ForegroundColor Cyan
        return
    }
    
    # Skip push if multi-platform build already pushed
    if ($MultiPlatform) {
        Write-Host "✅ Multi-platform image pushed to Docker Hub during build" -ForegroundColor Green
        Write-Host "Image URL: docker.io/$fullImageName" -ForegroundColor Cyan
        Write-Host "Docker Hub URL: https://hub.docker.com/r/$imageName" -ForegroundColor Cyan
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

# Example usage instructions
Write-Host "`nExample usage:" -ForegroundColor Yellow
Write-Host "# Test locally" -ForegroundColor Gray
Write-Host "docker run -p 5001:5001 --name azure-mcp-host $fullImageName" -ForegroundColor Gray
Write-Host "" -ForegroundColor Gray
Write-Host "# In docker-compose.yml" -ForegroundColor Gray
Write-Host "services:" -ForegroundColor Gray
Write-Host "  azure-mcp-host:" -ForegroundColor Gray
Write-Host "    image: docker.io/$fullImageName" -ForegroundColor Gray
Write-Host "    ports:" -ForegroundColor Gray
Write-Host "      - '5001:5001'" -ForegroundColor Gray