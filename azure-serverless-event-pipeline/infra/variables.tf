# ---------------------------------------------------------------------------
# variables.tf — Input variables for the serverless event pipeline
# ---------------------------------------------------------------------------
# Centralised variable definitions keep the root module clean and make it easy
# to override values per environment via .tfvars files.
# ---------------------------------------------------------------------------

# ---- General ----------------------------------------------------------------

variable "project_name" {
  description = "Short name used as a prefix for all resources."
  type        = string
  default     = "evtpipe"

  validation {
    condition     = can(regex("^[a-z0-9]{3,10}$", var.project_name))
    error_message = "project_name must be 3-10 lowercase alphanumeric characters."
  }
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus2"
}

variable "tags" {
  description = "Default tags applied to every resource."
  type        = map(string)
  default     = {}
}

# ---- Networking -------------------------------------------------------------

variable "vnet_address_space" {
  description = "Address space for the virtual network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_functions_prefix" {
  description = "CIDR prefix for the Functions integration subnet."
  type        = string
  default     = "10.0.1.0/24"
}

variable "subnet_private_endpoints_prefix" {
  description = "CIDR prefix for Private Endpoint subnet."
  type        = string
  default     = "10.0.2.0/24"
}

# ---- Cosmos DB --------------------------------------------------------------

variable "cosmos_db_throughput" {
  description = "Provisioned RU/s for the Cosmos DB container (autoscale max)."
  type        = number
  default     = 4000
}

# ---- Service Bus ------------------------------------------------------------

variable "service_bus_sku" {
  description = "Service Bus SKU (Premium required for Private Endpoints)."
  type        = string
  default     = "Premium"
}

# ---- API Management ---------------------------------------------------------

variable "apim_sku" {
  description = "API Management SKU name."
  type        = string
  default     = "Developer"
}

variable "apim_publisher_name" {
  description = "Publisher name shown in the APIM developer portal."
  type        = string
  default     = "Contoso Events"
}

variable "apim_publisher_email" {
  description = "Publisher contact email for APIM."
  type        = string
  default     = "platform-team@contoso.com"
}

# ---- Function App -----------------------------------------------------------

variable "function_app_sku" {
  description = "App Service Plan SKU for the Function App."
  type        = string
  default     = "EP1" # Elastic Premium — supports VNet integration + Private Endpoints
}
