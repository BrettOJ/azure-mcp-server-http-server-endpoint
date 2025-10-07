using Azure.Mcp.Core.Areas.Server.Commands;
using Azure.Mcp.Core.Areas.Server.Options;
using Azure.Mcp.Core.Extensions;
using Azure.Mcp.Core.Commands;
using Azure.Mcp.Core.Services.Azure.ResourceGroup;
using Azure.Mcp.Core.Services.Azure.Subscription;
using Azure.Mcp.Core.Services.Azure.Tenant;
using Azure.Mcp.Core.Services.Caching;
using Azure.Mcp.Core.Services.ProcessExecution;
using Azure.Mcp.Core.Services.Time;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

// Get the bind URL
string expectedUrl = Environment.GetEnvironmentVariable("ASPNETCORE_URLS") ?? "http://127.0.0.1:5001";

// Create the web application builder
var builder = WebApplication.CreateBuilder(args);

// Console logging is handy in containers
builder.Logging.ClearProviders();
builder.Logging.AddSimpleConsole(o =>
{
    o.SingleLine = true;
    o.TimestampFormat = "yyyy-MM-ddTHH:mm:ss.fffK ";
});
builder.Logging.SetMinimumLevel(LogLevel.Trace);

// Configure URLs
builder.WebHost.UseUrls(expectedUrl);

// Add CORS support
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyMethod()
              .AllowAnyHeader();
    });
});

// IMPORTANT: enable HTTP transport by setting EnableInsecureTransports = true
var opts = new ServiceStartOptions
{
    // Pick the discovery mode you want; 'All' exposes registry + command-factory tools
    Mode = "all",
    EnableInsecureTransports = true,

    // Optional: scope to specific tool namespaces (leave null for everything)
    // Namespace = new[] { "bestpractices", "storage", "keyvault" },

    // Optional: read-only for safety in shared environments
    ReadOnly = false,

    // Optional: disable confirmation prompts for high-risk operations (use with care)
    // InsecureDisableElicitation = true,
};

// Configure required services (from main server's ConfigureServices method)
builder.Services.ConfigureOpenTelemetry();
builder.Services.AddMemoryCache();

// Add core services that MCP runtime requires
builder.Services.AddSingleton<Azure.Mcp.Core.Services.Caching.ICacheService, Azure.Mcp.Core.Services.Caching.CacheService>();
builder.Services.AddSingleton<Azure.Mcp.Core.Services.ProcessExecution.IExternalProcessService, Azure.Mcp.Core.Services.ProcessExecution.ExternalProcessService>();
builder.Services.AddSingleton<Azure.Mcp.Core.Services.Time.IDateTimeProvider, Azure.Mcp.Core.Services.Time.DateTimeProvider>();
builder.Services.AddSingleton<Azure.Mcp.Core.Services.Azure.Tenant.ITenantService, Azure.Mcp.Core.Services.Azure.Tenant.TenantService>();
builder.Services.AddSingleton<Azure.Mcp.Core.Services.Azure.ResourceGroup.IResourceGroupService, Azure.Mcp.Core.Services.Azure.ResourceGroup.ResourceGroupService>();
builder.Services.AddSingleton<Azure.Mcp.Core.Services.Azure.Subscription.ISubscriptionService, Azure.Mcp.Core.Services.Azure.Subscription.SubscriptionService>();
builder.Services.AddSingleton<Azure.Mcp.Core.Commands.CommandFactory>();

// Add Azure MCP Server services
builder.Services.AddAzureMcpServer(opts);

// Build the web application
var app = builder.Build();

var log = app.Services.GetRequiredService<ILoggerFactory>().CreateLogger("HttpHost");

// Log the expected bind address
log.LogInformation("Azure MCP HTTP host starting...");
log.LogInformation("Expected bind address: {ExpectedUrl}", expectedUrl);
log.LogInformation("Transport: HTTP (EnableInsecureTransports=true).");

// Configure the HTTP request pipeline
app.UseCors("AllowAll");
app.UseRouting();
app.MapMcp();  // This is the key missing piece!

// Start the web application and keep it running
await app.RunAsync();
