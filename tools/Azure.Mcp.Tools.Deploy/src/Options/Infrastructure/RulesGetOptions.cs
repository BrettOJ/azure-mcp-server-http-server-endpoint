// Copyright (c) Microsoft Corporation.
// Licensed under the MIT License.

namespace Azure.Mcp.Tools.Deploy.Options.Infrastructure;

public sealed class RulesGetOptions
{
    public string DeploymentTool { get; set; } = string.Empty;
    public string IacType { get; set; } = string.Empty;
    public string ResourceTypes { get; set; } = string.Empty;
}
