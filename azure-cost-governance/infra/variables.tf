# ──────────────────────────────────────────────────────────────────────────────
# Azure Cost Governance — Variables
# ──────────────────────────────────────────────────────────────────────────────

variable "environment" {
  description = "Deployment environment (dev, prod)."
  type        = string
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be 'dev' or 'prod'."
  }
}

variable "location" {
  description = "Primary Azure region for all resources."
  type        = string
  default     = "eastus2"
}

variable "project" {
  description = "Project name used in resource naming and tagging."
  type        = string
  default     = "cost-governance"
}

variable "subscription_id" {
  description = "Azure subscription ID that the automation monitors."
  type        = string
}

variable "notification_email" {
  description = "Email address for cost report delivery."
  type        = string
  default     = ""
}

variable "teams_webhook_url" {
  description = "Microsoft Teams incoming webhook URL for alerts."
  type        = string
  default     = ""
  sensitive   = true
}

variable "required_tags" {
  description = "Tags that must be present on every resource."
  type        = list(string)
  default     = ["Environment", "Owner", "CostCenter"]
}

variable "allowed_locations" {
  description = "Azure regions where resources may be created."
  type        = list(string)
  default     = ["eastus2", "westus2", "centralus"]
}

variable "cost_report_schedule" {
  description = "Cron expression for the weekly cost-report Logic App (UTC)."
  type        = string
  default     = "0 8 * * 1" # Every Monday at 08:00 UTC
}

# ──────────────────────────────────────────────────────────────────────────────
# Common tags applied to every resource via the `local.tags` map.
# ──────────────────────────────────────────────────────────────────────────────

variable "extra_tags" {
  description = "Additional tags merged into the default set."
  type        = map(string)
  default     = {}
}
