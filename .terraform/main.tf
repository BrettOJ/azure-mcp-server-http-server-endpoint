
terraform {
  required_version = ">= 1.9.7"
}
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.47.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "3.6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5.0"
    }
  }
}

provider "azurerm" {
  storage_use_azuread = false
  use_msi             = false
  tenant_id           = "f3c9952d-3ea5-4539-bd9a-7e1093f8a1b6" #konjur tenant id
  subscription_id     = "95328200-66a3-438f-9641-aeeb101e5e37"
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
  version = "0.2.1"

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
module "avm-res-operationalinsights-workspace" {
  source  = "Azure/avm-res-operationalinsights-workspace/azurerm"
  version = "0.4.2"

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
module "avm-res-managedidentity-userassignedidentity" {
  source  = "Azure/avm-res-managedidentity-userassignedidentity/azurerm"
  version = "0.3.4"

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
module "avm-res-containerinstance-containergroup" {
  source  = "Azure/avm-res-containerinstance-containergroup/azurerm"
  version = "0.2.0"

  name                = "ci-azmcp-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = module.resource_group.name
  os_type             = "Linux"
  restart_policy      = "Always"
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
        AZURE_CLIENT_ID       = module.avm-res-managedidentity-userassignedidentity.client_id
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
      volumes = {}
    }
  }

  # Managed Identity configuration
managed_identities = {
    system_assigned            = false
    user_assigned_resource_ids = [module.avm-res-managedidentity-userassignedidentity.resource_id]
  }

  # Log Analytics integration for monitoring
diagnostics_log_analytics = {
    workspace_id  = module.avm-res-operationalinsights-workspace.resource.workspace_id
    workspace_key = module.avm-res-operationalinsights-workspace.resource.primary_shared_key
}

  tags = merge(var.tags, {
    Environment   = var.environment
    Application   = "Azure-MCP-Server"
    DeployedBy    = "Terraform"
  })

  depends_on = [
    module.resource_group,
    module.avm-res-managedidentity-userassignedidentity,
    module.avm-res-operationalinsights-workspace

  ]
}

# Role assignment for the managed identity to access Azure resources
resource "azurerm_role_assignment" "contributor" {
  count                = var.enable_contributor_access ? 1 : 0
  scope                = module.resource_group.resource_id
  role_definition_name = "Contributor"
  principal_id         = module.avm-res-managedidentity-userassignedidentity.principal_id

  depends_on = [module.avm-res-managedidentity-userassignedidentity]
}

# Role assignment for reader access to subscription (minimal permissions)
resource "azurerm_role_assignment" "reader" {
  count                = var.enable_subscription_reader ? 1 : 0
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Reader"
  principal_id         = module.avm-res-managedidentity-userassignedidentity.principal_id

  depends_on = [module.avm-res-managedidentity-userassignedidentity]
}