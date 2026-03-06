# --------------------------------------------------------------------------
# Data Sources
# --------------------------------------------------------------------------

# Current Azure context — used to scope RBAC and Key Vault policies
data "azurerm_client_config" "current" {}

# --------------------------------------------------------------------------
# Locals — Naming + Tagging
# --------------------------------------------------------------------------

locals {
  # Consistent naming convention: {resource}-{project}-{env}-{region}
  name_prefix = "${var.project}-${var.environment}-${var.location}"

  # Mandatory tags applied to every resource for governance and cost tracking
  default_tags = {
    environment = var.environment
    owner       = var.owner
    cost-center = var.cost_center
    project     = var.project
    managed-by  = "terraform"
  }

  tags = merge(local.default_tags, var.extra_tags)
}

# --------------------------------------------------------------------------
# Resource Group
# --------------------------------------------------------------------------

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.tags
}

# --------------------------------------------------------------------------
# Log Analytics Workspace — shared sink for Container Insights and diagnostics
# --------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"

  # 30-day retention is the free tier; increase for production audit requirements
  retention_in_days = var.environment == "prod" ? 90 : 30

  tags = local.tags
}
