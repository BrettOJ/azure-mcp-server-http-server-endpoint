# Azure MCP Server Container Instance Deployment
# This configuration deploys the Azure MCP Server container to Azure Container Instances
# using Azure Verified Modules following Terraform best practices.

terraform {
  required_version = ">= 1.9.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.1"
    }
  }
}

# Configure the Azure Provider
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Generate a random suffix for unique resource naming
resource "random_string" "suffix" {
  length  = 8
  upper   = false
  special = false
}

# Data source for current client configuration
data "azurerm_client_config" "current" {}

# Create Resource Group using Azure Verified Module
module "resource_group" {
  source  = "Azure/avm-res-resources-resourcegroup/azurerm"
  version = "~> 0.1.0"

  name     = var.resource_group_name != "" ? var.resource_group_name : "rg-azmcp-${random_string.suffix.result}"
  location = var.location

  tags = merge(var.tags, {
    Environment   = var.environment
    Application   = "Azure-MCP-Server"
    DeployedBy    = "Terraform"
    DeployedDate  = formatdate("YYYY-MM-DD", timestamp())
  })
}

# Create Log Analytics Workspace for Container Insights
module "log_analytics" {
  source  = "Azure/avm-res-operationalinsights-workspace/azurerm"
  version = "~> 0.4.0"

  name                = "law-azmcp-${random_string.suffix.result}"
  resource_group_name = module.resource_group.name
  location            = var.location
  log_analytics_workspace_sku                 = "PerGB2018"
  log_analytics_workspace_retention_in_days   = 30

  tags = merge(var.tags, {
    Environment   = var.environment
    Application   = "Azure-MCP-Server"
    DeployedBy    = "Terraform"
  })

  depends_on = [module.resource_group]
}

# Create User Managed Identity for Container Instance
module "managed_identity" {
  source  = "Azure/avm-res-managedidentity-userassignedidentity/azurerm"
  version = "~> 0.4.0"

  name                = "mi-azmcp-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = module.resource_group.name

  tags = merge(var.tags, {
    Environment   = var.environment
    Application   = "Azure-MCP-Server"
    DeployedBy    = "Terraform"
  })

  depends_on = [module.resource_group]
}

# Create Container Instance using Azure Verified Module
module "container_instance" {
  source  = "Azure/avm-res-containerinstance-containergroup/azurerm"
  version = "~> 0.3.0"

  name                = "ci-azmcp-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = module.resource_group.name
  os_type             = "Linux"
  restart_policy      = "Always"
  ip_address_type     = "Public"
  dns_name_label      = "azmcp-${random_string.suffix.result}"

  # Container configuration
  containers = {
    azure-mcp-server = {
      name   = "azure-mcp-server"
      image  = var.container_image
      cpu    = var.container_cpu
      memory = var.container_memory
      
      # Environment variables for Azure authentication and configuration
      environment_variables = {
        AZURE_CLIENT_ID       = module.managed_identity.client_id
        AZURE_TENANT_ID       = data.azurerm_client_config.current.tenant_id
        ASPNETCORE_ENVIRONMENT = var.environment
        ASPNETCORE_URLS       = "http://+:8080"
      }

      # Secure environment variables (if needed)
      secure_environment_variables = var.secure_environment_variables

      # Port configuration
      ports = [
        {
          port     = 8080
          protocol = "TCP"
        }
      ]

      # Health probe configuration
      liveness_probe = {
        http_get = [
          {
            path   = "/health"
            port   = 8080
            scheme = "HTTP"
          }
        ]
        initial_delay_seconds = 30
        period_seconds        = 30
        timeout_seconds       = 5
        failure_threshold     = 3
      }

      readiness_probe = {
        http_get = [
          {
            path   = "/ready"
            port   = 8080
            scheme = "HTTP"
          }
        ]
        initial_delay_seconds = 10
        period_seconds        = 10
        timeout_seconds       = 3
        failure_threshold     = 3
      }
    }
  }

  # Managed Identity configuration
  identity = {
    type = "UserAssigned"
    identity_ids = [
      module.managed_identity.resource_id
    ]
  }

  # Log Analytics integration for monitoring
  diagnostics = {
    log_analytics = [
      {
        workspace_id = module.log_analytics.resource_id
      }
    ]
  }

  tags = merge(var.tags, {
    Environment   = var.environment
    Application   = "Azure-MCP-Server"
    DeployedBy    = "Terraform"
  })

  depends_on = [
    module.resource_group,
    module.managed_identity,
    module.log_analytics
  ]
}

# Role assignment for the managed identity to access Azure resources
resource "azurerm_role_assignment" "contributor" {
  count                = var.enable_contributor_access ? 1 : 0
  scope                = module.resource_group.resource_id
  role_definition_name = "Contributor"
  principal_id         = module.managed_identity.principal_id

  depends_on = [module.managed_identity]
}

# Role assignment for reader access to subscription (minimal permissions)
resource "azurerm_role_assignment" "reader" {
  count                = var.enable_subscription_reader ? 1 : 0
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Reader"
  principal_id         = module.managed_identity.principal_id

  depends_on = [module.managed_identity]
}