# ---------------------------------------------------------------------------
# Root variables — every value that changes between environments lives here.
# Environment-specific overrides are in environments/*.tfvars.
# ---------------------------------------------------------------------------

# ── Identity & Subscription ─────────────────────────────────────────────────

variable "tenant_id" {
  description = "Azure AD tenant ID."
  type        = string
}

variable "subscription_id" {
  description = "Target Azure subscription for the landing zone deployment."
  type        = string
}

# ── Environment Metadata ─────────────────────────────────────────────────────

variable "environment" {
  description = "Deployment environment name (dev, staging, prod)."
  type        = string
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod."
  }
}

variable "location" {
  description = "Primary Azure region for all resources."
  type        = string
  default     = "uksouth"
}

variable "owner" {
  description = "Team or individual responsible for this landing zone."
  type        = string
  default     = "platform-engineering"
}

variable "cost_center" {
  description = "Finance cost centre code applied to every resource."
  type        = string
  default     = "CC-1000"
}

# ── Tags ─────────────────────────────────────────────────────────────────────

variable "default_tags" {
  description = "Baseline tags applied to all resources. Module-level tags are merged on top."
  type        = map(string)
  default     = {}
}

# ── Networking ───────────────────────────────────────────────────────────────

variable "hub_vnet_address_space" {
  description = "CIDR block for the hub virtual network."
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "firewall_subnet_prefix" {
  description = "CIDR for the AzureFirewallSubnet inside the hub VNet."
  type        = string
  default     = "10.0.1.0/26"
}

variable "bastion_subnet_prefix" {
  description = "CIDR for the AzureBastionSubnet inside the hub VNet."
  type        = string
  default     = "10.0.2.0/26"
}

variable "gateway_subnet_prefix" {
  description = "CIDR for the GatewaySubnet inside the hub VNet."
  type        = string
  default     = "10.0.3.0/27"
}

variable "spoke_vnets" {
  description = "Map of spoke VNets to peer with the hub. Key = name, value = address space."
  type = map(object({
    address_space       = list(string)
    resource_group_name = string
  }))
  default = {}
}

variable "private_dns_zone_names" {
  description = "List of Private DNS Zone names to create and link to the hub VNet."
  type        = list(string)
  default = [
    "privatelink.blob.core.windows.net",
    "privatelink.database.windows.net",
    "privatelink.vaultcore.azure.net",
    "privatelink.azurewebsites.net",
  ]
}

variable "firewall_sku_tier" {
  description = "Azure Firewall SKU tier (Standard or Premium)."
  type        = string
  default     = "Standard"
  validation {
    condition     = contains(["Standard", "Premium"], var.firewall_sku_tier)
    error_message = "firewall_sku_tier must be Standard or Premium."
  }
}

# ── Management Groups ────────────────────────────────────────────────────────

variable "root_management_group_display_name" {
  description = "Display name for the top-level management group."
  type        = string
  default     = "Contoso"
}

# ── Policy ───────────────────────────────────────────────────────────────────

variable "allowed_locations" {
  description = "Azure regions workloads are allowed to deploy into."
  type        = list(string)
  default     = ["uksouth", "ukwest"]
}

# ── Identity ─────────────────────────────────────────────────────────────────

variable "platform_identity_name" {
  description = "Name of the user-assigned managed identity used by the platform team."
  type        = string
  default     = "id-platform-automation"
}
