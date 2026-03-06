# --------------------------------------------------------------------------
# General
# --------------------------------------------------------------------------

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "eastus"
}

variable "project" {
  description = "Project name used in resource naming and tagging."
  type        = string
  default     = "aks-cluster"
}

variable "owner" {
  description = "Team or individual responsible for these resources."
  type        = string
  default     = "platform-engineering"
}

variable "cost_center" {
  description = "Cost center code for billing attribution."
  type        = string
  default     = "CC-1234"
}

# --------------------------------------------------------------------------
# Networking
# --------------------------------------------------------------------------

variable "vnet_address_space" {
  description = "Address space for the virtual network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "aks_subnet_prefix" {
  description = "CIDR block for the AKS node subnet. Sized /22 to support overlay networking pod CIDRs."
  type        = string
  default     = "10.0.2.0/22"
}

variable "appgw_subnet_prefix" {
  description = "CIDR block for the Application Gateway subnet. Minimum /24 required by Azure."
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_endpoint_subnet_prefix" {
  description = "CIDR block for private endpoints (Key Vault, ACR, etc.)."
  type        = string
  default     = "10.0.8.0/24"
}

# --------------------------------------------------------------------------
# AKS
# --------------------------------------------------------------------------

variable "kubernetes_version" {
  description = "Kubernetes version for the AKS control plane and default node pool."
  type        = string
  default     = "1.29"
}

variable "system_node_pool_vm_size" {
  description = "VM size for the system node pool (runs kube-system workloads)."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "system_node_pool_count" {
  description = "Fixed node count for the system pool. System pools are not autoscaled to ensure stability."
  type        = number
  default     = 2
}

variable "workload_node_pool_vm_size" {
  description = "VM size for the workload node pool."
  type        = string
  default     = "Standard_D4s_v5"
}

variable "workload_node_pool_min_count" {
  description = "Minimum node count for the workload pool autoscaler."
  type        = number
  default     = 2
}

variable "workload_node_pool_max_count" {
  description = "Maximum node count for the workload pool autoscaler."
  type        = number
  default     = 10
}

variable "private_cluster_enabled" {
  description = "When true, the Kubernetes API server is only accessible via private endpoint."
  type        = bool
  default     = true
}

# --------------------------------------------------------------------------
# Key Vault
# --------------------------------------------------------------------------

variable "keyvault_sku" {
  description = "SKU tier for Key Vault. Use premium for HSM-backed keys in production."
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.keyvault_sku)
    error_message = "Key Vault SKU must be standard or premium."
  }
}

# --------------------------------------------------------------------------
# Tags
# --------------------------------------------------------------------------

variable "extra_tags" {
  description = "Additional tags to merge with the default tag set."
  type        = map(string)
  default     = {}
}
