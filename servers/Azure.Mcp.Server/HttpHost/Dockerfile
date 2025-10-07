# Multi-stage build for Azure MCP HTTP Host
FROM mcr.microsoft.com/dotnet/sdk:10.0-preview AS build
WORKDIR /src

# Copy project files
COPY ["servers/Azure.Mcp.Server/HttpHost/Azure.Mcp.Server.HttpHost.csproj", "servers/Azure.Mcp.Server/HttpHost/"]
COPY ["core/Azure.Mcp.Core/src/Azure.Mcp.Core.csproj", "core/Azure.Mcp.Core/src/"]
COPY ["core/Microsoft.Mcp.Core/src/Microsoft.Mcp.Core.csproj", "core/Microsoft.Mcp.Core/src/"]

# Copy package management files
COPY ["Directory.Build.props", "./"]
COPY ["Directory.Build.targets", "./"]
COPY ["Directory.Packages.props", "./"]
COPY ["nuget.config", "./"]
COPY ["global.json", "./"]

# Restore dependencies
RUN dotnet restore "servers/Azure.Mcp.Server/HttpHost/Azure.Mcp.Server.HttpHost.csproj"

# Copy source code
COPY . .

# Build the application
WORKDIR "/src/servers/Azure.Mcp.Server/HttpHost"
RUN dotnet build "Azure.Mcp.Server.HttpHost.csproj" -c Release -o /app/build

# Publish the application
RUN dotnet publish "Azure.Mcp.Server.HttpHost.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:9.0 AS runtime
WORKDIR /app

# Install curl for health checks
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

# Create a non-root user for security
RUN useradd -m -u 1001 -s /bin/bash appuser || adduser -D -u 1001 -s /bin/bash appuser 2>/dev/null || true

# Copy published application
COPY --from=build /app/publish .

# Change ownership to appuser
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port 5001 (default port for the HTTP host)
EXPOSE 5001

# Set environment variables
ENV ASPNETCORE_URLS=http://0.0.0.0:5001
ENV ASPNETCORE_ENVIRONMENT=Production
ENV DOTNET_RUNNING_IN_CONTAINER=true

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
  CMD curl -f http://localhost:5001/ || exit 1

# Entry point
ENTRYPOINT ["dotnet", "Azure.Mcp.Server.HttpHost.dll"]