# --------------------------------------------------------------------------
# Root module: resource group, shared data sources, and tagging baseline
# --------------------------------------------------------------------------

locals {
  # Consistent naming convention: {project}-{resource}-{env}-{region_short}
  name_prefix = "${var.project_name}-${var.environment}"

  region_short = {
    "eastus"         = "eus"
    "eastus2"        = "eus2"
    "westus2"        = "wus2"
    "westeurope"     = "weu"
    "northeurope"    = "neu"
    "centralus"      = "cus"
    "southcentralus" = "scus"
  }

  region_abbr = lookup(local.region_short, var.location, replace(var.location, "/[aeiou]/", ""))

  # Every resource inherits these tags for cost tracking, ownership, and automation.
  common_tags = merge(
    {
      project     = var.project_name
      environment = var.environment
      managed_by  = "terraform"
      repository  = "azure-portfolio/azure-observability-stack"
    },
    var.extra_tags,
  )
}

# Single resource group keeps the entire observability stack co-located,
# simplifying RBAC scoping and cost attribution.
resource "azurerm_resource_group" "observability" {
  name     = "rg-${local.name_prefix}-${local.region_abbr}"
  location = var.location
  tags     = local.common_tags
}

# Current client identity — used for RBAC assignments (e.g., Grafana admin).
data "azurerm_client_config" "current" {}
