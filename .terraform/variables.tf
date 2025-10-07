# Variables for Azure MCP Server Container Instance Deployment
# These variables provide flexibility and customization for the deployment

variable "location" {
  description = "Azure region where resources will be deployed"
  type        = string
  default     = "East US"
  
  validation {
    condition = can(regex("^[A-Za-z0-9 ]+$", var.location))
    error_message = "Location must be a valid Azure region name."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "resource_group_name" {
  description = "Name of the resource group. If empty, a unique name will be generated."
  type        = string
  default     = ""
}

variable "container_image" {
  description = "Container image for the Azure MCP Server"
  type        = string
  default     = null

  validation {
    condition = can(regex("^[a-zA-Z0-9.-]+/[a-zA-Z0-9.-]+:[a-zA-Z0-9.-]+$", var.container_image))
    error_message = "Container image must be in format: registry/repository:tag."
  }
}

variable "container_cpu" {
  description = "CPU allocation for the container (in cores)"
  type        = number
  default     = 1
  
  validation {
    condition = var.container_cpu >= 0.1 && var.container_cpu <= 4
    error_message = "Container CPU must be between 0.1 and 4 cores."
  }
}

variable "container_memory" {
  description = "Memory allocation for the container (in GB)"
  type        = number
  default     = 2
  
  validation {
    condition = var.container_memory >= 0.5 && var.container_memory <= 16
    error_message = "Container memory must be between 0.5 and 16 GB."
  }
}

variable "enable_contributor_access" {
  description = "Grant Contributor access to the managed identity for the resource group"
  type        = bool
  default     = true
}

variable "enable_subscription_reader" {
  description = "Grant Reader access to the managed identity for the subscription"
  type        = bool
  default     = true
}

variable "secure_environment_variables" {
  description = "Secure environment variables for the container (sensitive data)"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "Azure-MCP-Server"
    Owner       = "Infrastructure-Team"
    CostCenter  = "Engineering"
  }
  
  validation {
    condition = alltrue([
      for tag_key, tag_value in var.tags : can(regex("^[a-zA-Z0-9-_. ]+$", tag_key))
    ])
    error_message = "Tag keys must only contain alphanumeric characters, hyphens, underscores, periods, and spaces."
  }
}