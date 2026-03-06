# -----------------------------------------------------------------------------
# General
# -----------------------------------------------------------------------------

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus2"
}

variable "project_name" {
  description = "Short project identifier used in resource naming"
  type        = string
  default     = "zt"
}

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------

variable "hub_vnet_address_space" {
  description = "Address space for the hub VNet"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "spoke_vnet_address_space" {
  description = "Address space for the spoke VNet"
  type        = list(string)
  default     = ["10.1.0.0/16"]
}

variable "firewall_subnet_prefix" {
  description = "CIDR for AzureFirewallSubnet (must be named exactly this)"
  type        = string
  default     = "10.0.1.0/24"
}

variable "management_subnet_prefix" {
  description = "CIDR for the management/jumpbox subnet"
  type        = string
  default     = "10.0.2.0/24"
}

variable "app_integration_subnet_prefix" {
  description = "CIDR for App Service VNet integration (delegated subnet)"
  type        = string
  default     = "10.1.1.0/24"
}

variable "private_endpoint_subnet_prefix" {
  description = "CIDR for Private Endpoints"
  type        = string
  default     = "10.1.2.0/24"
}

variable "data_subnet_prefix" {
  description = "CIDR for data-tier resources"
  type        = string
  default     = "10.1.3.0/24"
}

# -----------------------------------------------------------------------------
# App Service
# -----------------------------------------------------------------------------

variable "app_service_sku" {
  description = "SKU for the App Service Plan (must be Premium for VNet integration)"
  type        = string
  default     = "P1v3"
}

# -----------------------------------------------------------------------------
# Firewall
# -----------------------------------------------------------------------------

variable "firewall_sku_tier" {
  description = "Azure Firewall SKU tier — Premium adds TLS inspection and IDPS"
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Standard", "Premium"], var.firewall_sku_tier)
    error_message = "Firewall SKU must be Standard or Premium."
  }
}

# -----------------------------------------------------------------------------
# Tags
# -----------------------------------------------------------------------------

variable "extra_tags" {
  description = "Additional tags to merge onto every resource"
  type        = map(string)
  default     = {}
}

# Computed locals — central place for naming conventions and shared tags
locals {
  # Consistent naming: {project}-{resource}-{environment}
  name_prefix = "${var.project_name}-${var.environment}"

  # Every resource gets these tags for cost tracking, ownership, and compliance
  common_tags = merge({
    Project     = "azure-zero-trust-architecture"
    Environment = var.environment
    ManagedBy   = "terraform"
    SecurityModel = "zero-trust"
  }, var.extra_tags)
}
