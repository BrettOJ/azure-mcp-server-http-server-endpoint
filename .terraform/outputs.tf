# Outputs for Azure MCP Server Container Instance Deployment
# These outputs provide important information about the deployed resources

output "resource_group_name" {
  description = "Name of the created resource group"
  value       = module.resource_group.name
}

output "resource_group_id" {
  description = "Resource ID of the created resource group"
  value       = module.resource_group.resource_id
}

output "container_instance_name" {
  description = "Name of the container instance"
  value       = module.container_instance.name
}

output "container_instance_id" {
  description = "Resource ID of the container instance"
  value       = module.container_instance.resource_id
}

output "container_public_ip" {
  description = "Public IP address of the container instance"
  value       = module.container_instance.ip_address
}

output "container_fqdn" {
  description = "Fully qualified domain name of the container instance"
  value       = module.container_instance.fqdn
}

output "container_url" {
  description = "Complete URL to access the Azure MCP Server"
  value       = "http://${module.container_instance.fqdn}:8080"
}

output "managed_identity_client_id" {
  description = "Client ID of the managed identity"
  value       = module.managed_identity.client_id
}

output "managed_identity_principal_id" {
  description = "Principal ID of the managed identity"
  value       = module.managed_identity.principal_id
}

output "log_analytics_workspace_name" {
  description = "Name of the Log Analytics workspace"
  value       = module.log_analytics.name
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace"
  value       = module.log_analytics.resource_id
}

output "deployment_summary" {
  description = "Summary of the deployed resources"
  value = {
    resource_group        = module.resource_group.name
    location             = var.location
    environment          = var.environment
    container_image      = var.container_image
    container_url        = "http://${module.container_instance.fqdn}:8080"
    managed_identity_id  = module.managed_identity.client_id
    log_analytics_name   = module.log_analytics.name
  }
}