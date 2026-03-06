variable "location" {
  description = "Azure region for identity resources."
  type        = string
}

variable "environment" {
  description = "Deployment environment (dev, staging, prod)."
  type        = string
}

variable "platform_identity_name" {
  description = "Base name for the platform automation managed identity."
  type        = string
}

variable "connectivity_resource_group_id" {
  description = "Resource ID of the connectivity resource group (for scoped RBAC)."
  type        = string
}

variable "common_tags" {
  description = "Tags applied to all resources in this module."
  type        = map(string)
  default     = {}
}
