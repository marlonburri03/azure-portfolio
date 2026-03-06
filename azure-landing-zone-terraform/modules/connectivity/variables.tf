variable "location" {
  description = "Azure region for connectivity resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
}

variable "hub_vnet_address_space" {
  description = "Address space for the hub virtual network."
  type        = list(string)
}

variable "firewall_subnet_prefix" {
  description = "CIDR prefix for the AzureFirewallSubnet."
  type        = string
}

variable "bastion_subnet_prefix" {
  description = "CIDR prefix for the AzureBastionSubnet."
  type        = string
}

variable "gateway_subnet_prefix" {
  description = "CIDR prefix for the GatewaySubnet."
  type        = string
}

variable "spoke_vnets" {
  description = "Map of spoke VNets to create and peer with the hub."
  type = map(object({
    address_space       = list(string)
    resource_group_name = string
  }))
  default = {}
}

variable "private_dns_zone_names" {
  description = "List of Private DNS zone names to create."
  type        = list(string)
}

variable "firewall_sku_tier" {
  description = "Azure Firewall SKU tier (Standard or Premium)."
  type        = string
  default     = "Standard"
}

variable "common_tags" {
  description = "Tags applied to all resources in this module."
  type        = map(string)
  default     = {}
}
