# ──────────────────────────────────────────────────────────────────────────────
# Azure Cost Governance — Core Resources
# ──────────────────────────────────────────────────────────────────────────────

locals {
  # Consistent naming: <type>-<project>-<env>
  name_prefix = "${var.project}-${var.environment}"

  tags = merge(
    {
      Environment = var.environment
      Project     = var.project
      ManagedBy   = "Terraform"
    },
    var.extra_tags,
  )
}

# ── Resource Group ──────────────────────────────────────────────────────────

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.tags
}

# ── Storage Account (backing store for Function App + report archive) ──────

resource "azurerm_storage_account" "main" {
  name                     = replace("st${local.name_prefix}", "-", "")
  resource_group_name      = azurerm_resource_group.main.name
  location                 = azurerm_resource_group.main.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # Enforce HTTPS-only to satisfy security baselines.
  enable_https_traffic_only = true
  min_tls_version           = "TLS1_2"

  tags = local.tags
}

# ── Key Vault (stores webhook URL and other secrets) ───────────────────────

resource "azurerm_key_vault" "main" {
  name                = "kv-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku_name            = "standard"
  tenant_id           = data.azurerm_client_config.current.tenant_id

  # Soft-delete is enabled by default since 2020; set retention period.
  soft_delete_retention_days = 7
  purge_protection_enabled   = false # Allow purge in dev; override in prod.

  tags = local.tags
}

# ── Data source for the current Azure context (tenant, object ID) ─────────

data "azurerm_client_config" "current" {}
