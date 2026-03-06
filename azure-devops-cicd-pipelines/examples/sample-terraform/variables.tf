# =============================================================================
# Variables for the sample Terraform configuration
# =============================================================================
# Default values target a minimal dev environment. Override per-environment
# using .tfvars files (e.g., environments/prod.tfvars).
# =============================================================================

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Azure region for all resources"
  type        = string
  default     = "eastus2"
}

variable "project_name" {
  description = "Project identifier used in resource naming"
  type        = string
  default     = "portfolio"
}

variable "owner" {
  description = "Team or individual responsible for these resources"
  type        = string
}

variable "cost_center" {
  description = "Finance cost center code for chargeback"
  type        = string
}

# ---------------------------------------------------------------------------
# AKS Configuration
# ---------------------------------------------------------------------------

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS cluster"
  type        = string
  default     = "1.29"
}

variable "aks_node_vm_size" {
  description = "VM size for AKS default node pool"
  type        = string
  default     = "Standard_D4s_v5"
}

variable "aks_node_count" {
  description = "Number of nodes in the default node pool"
  type        = number
  default     = 3

  validation {
    condition     = var.aks_node_count >= 1 && var.aks_node_count <= 100
    error_message = "Node count must be between 1 and 100."
  }
}

# ---------------------------------------------------------------------------
# Networking
# ---------------------------------------------------------------------------

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "aks_subnet_prefix" {
  description = "Address prefix for the AKS subnet"
  type        = string
  default     = "10.0.0.0/20"
}

# ---------------------------------------------------------------------------
# ACR Configuration
# ---------------------------------------------------------------------------

variable "acr_replication_locations" {
  description = "Geo-replication locations for the container registry (prod only)"
  type        = list(string)
  default     = ["westus2", "westeurope"]
}
