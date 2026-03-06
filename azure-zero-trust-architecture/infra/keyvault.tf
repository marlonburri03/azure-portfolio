# =============================================================================
# Key Vault — secrets management with zero public exposure
#
# Zero Trust principle: Least-privilege. Access is granted exclusively via
# Azure RBAC (not legacy access policies), and the vault is reachable only
# through its Private Endpoint. Soft-delete and purge protection prevent
# accidental or malicious data destruction.
# =============================================================================

data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "main" {
  name                = "kv-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  tags                = local.common_tags

  sku_name = "standard"

  # RBAC authorization replaces legacy access policies — it provides finer
  # granularity and integrates with Azure AD Conditional Access.
  enable_rbac_authorization = true

  # Soft-delete is enforced by Azure (can't be disabled), but purge protection
  # adds a mandatory retention window even for Owner-role principals.
  purge_protection_enabled = true
  soft_delete_retention_days = 90

  # Block all public network access — the vault is reachable ONLY via
  # its Private Endpoint in the spoke VNet.
  public_network_access_enabled = false

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }
}

# -----------------------------------------------------------------------------
# RBAC — grant the App Service Managed Identity the minimum role to read
# secrets. No other permissions (keys, certificates) are needed.
# -----------------------------------------------------------------------------

resource "azurerm_role_assignment" "app_keyvault_secrets" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}

# Grant the deploying identity (CI/CD service principal) officer access
# so Terraform can manage secrets during deployment.
resource "azurerm_role_assignment" "deployer_keyvault_officer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# -----------------------------------------------------------------------------
# Diagnostic Settings
# -----------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "keyvault" {
  name                       = "diag-kv-${local.name_prefix}"
  target_resource_id         = azurerm_key_vault.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel.id

  enabled_log {
    category = "AuditEvent"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
