variable "root_display_name" {
  description = "Display name for the top-level custom management group."
  type        = string
}

variable "tenant_id" {
  description = "Azure AD tenant ID (used for naming conventions)."
  type        = string
}
