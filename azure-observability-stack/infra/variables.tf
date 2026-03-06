variable "environment" {
  description = "Deployment environment identifier (dev, staging, prod)"
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
  description = "Short project identifier used in resource naming"
  type        = string
  default     = "observability"
}

# --- Log Analytics -----------------------------------------------------------

variable "log_analytics_sku" {
  description = "SKU for the Log Analytics Workspace (PerGB2018 is pay-as-you-go)"
  type        = string
  default     = "PerGB2018"
}

variable "log_retention_days" {
  description = "Number of days to retain logs. 30 is free tier; production typically uses 90."
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "Retention must be between 30 and 730 days."
  }
}

# --- Grafana -----------------------------------------------------------------

variable "grafana_sku" {
  description = "SKU for Azure Managed Grafana (Standard is the only GA option)"
  type        = string
  default     = "Standard"
}

variable "grafana_admin_object_ids" {
  description = "Azure AD object IDs granted Grafana Admin role"
  type        = list(string)
  default     = []
}

# --- Alerting ----------------------------------------------------------------

variable "alert_email_recipients" {
  description = "Email addresses that receive alert notifications"
  type        = list(string)
  default     = []
}

variable "slack_webhook_url" {
  description = "Slack incoming webhook URL for alert notifications"
  type        = string
  default     = ""
  sensitive   = true
}

variable "teams_webhook_url" {
  description = "Microsoft Teams incoming webhook URL for alert notifications"
  type        = string
  default     = ""
  sensitive   = true
}

# --- Tags --------------------------------------------------------------------

variable "extra_tags" {
  description = "Additional tags merged onto every resource"
  type        = map(string)
  default     = {}
}
