variable "landing_zones_management_group_id" {
  description = "Resource ID of the Landing Zones management group."
  type        = string
}

variable "allowed_locations" {
  description = "Azure regions workloads are permitted to deploy into."
  type        = list(string)
}

variable "environment" {
  description = "Current environment (dev, staging, prod). Influences policy enforcement mode."
  type        = string
}

variable "common_tags" {
  description = "Tags propagated from the root module."
  type        = map(string)
  default     = {}
}
