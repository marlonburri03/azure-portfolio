# =============================================================================
# Microsoft Sentinel — SIEM/SOAR with Log Analytics
#
# Zero Trust principle: Assume breach. Sentinel aggregates logs from every
# layer (network, identity, application, data) and applies analytics rules
# to detect threats that individual services cannot see in isolation.
# =============================================================================

resource "azurerm_log_analytics_workspace" "sentinel" {
  name                = "law-sentinel-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 90
  tags                = local.common_tags

  # Enable ingestion and query-time access control so each data source
  # can have independent RBAC permissions.
  internet_ingestion_enabled = false
  internet_query_enabled     = false
}

# Onboard the workspace to Sentinel
resource "azurerm_sentinel_log_analytics_workspace_onboarding" "main" {
  workspace_id = azurerm_log_analytics_workspace.sentinel.id
}

# -----------------------------------------------------------------------------
# Data Connectors — connect Azure-native log sources to Sentinel
# -----------------------------------------------------------------------------

# Azure AD sign-in and audit logs — detects compromised identities,
# impossible travel, and brute-force attacks.
resource "azurerm_sentinel_data_connector_azure_active_directory" "aad" {
  name                       = "dc-aad-${local.name_prefix}"
  log_analytics_workspace_id = azurerm_sentinel_log_analytics_workspace_onboarding.main.workspace_id
}

# Defender for Cloud alerts — surfaces VM, storage, and app service threats
resource "azurerm_sentinel_data_connector_azure_security_center" "defender" {
  name                       = "dc-defender-${local.name_prefix}"
  log_analytics_workspace_id = azurerm_sentinel_log_analytics_workspace_onboarding.main.workspace_id
}

# Azure Activity logs — detects unauthorized resource changes and deletions
resource "azurerm_sentinel_data_connector_azure_activity" "activity" {
  name                       = "dc-activity-${local.name_prefix}"
  log_analytics_workspace_id = azurerm_sentinel_log_analytics_workspace_onboarding.main.workspace_id
}

# -----------------------------------------------------------------------------
# Analytics Rules — basic built-in threat detection
# -----------------------------------------------------------------------------

resource "azurerm_sentinel_alert_rule_scheduled" "brute_force" {
  name                       = "ar-brute-force-${local.name_prefix}"
  log_analytics_workspace_id = azurerm_sentinel_log_analytics_workspace_onboarding.main.workspace_id
  display_name               = "Brute-Force SSH/RDP Attempts"
  description                = "Detects multiple failed sign-in attempts from a single IP within 10 minutes"
  severity                   = "High"
  enabled                    = true

  query = <<-QUERY
    SecurityEvent
    | where EventID in (4625, 4624)
    | summarize FailedAttempts = countif(EventID == 4625),
                SuccessfulAttempts = countif(EventID == 4624)
                by SourceIP = IpAddress, TargetAccount = Account, bin(TimeGenerated, 10m)
    | where FailedAttempts > 10
  QUERY

  query_frequency = "PT10M"
  query_period    = "PT10M"

  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics = ["CredentialAccess", "InitialAccess"]
}

resource "azurerm_sentinel_alert_rule_scheduled" "keyvault_mass_read" {
  name                       = "ar-kv-mass-read-${local.name_prefix}"
  log_analytics_workspace_id = azurerm_sentinel_log_analytics_workspace_onboarding.main.workspace_id
  display_name               = "Mass Key Vault Secret Access"
  description                = "Detects a principal reading an unusually high number of secrets in a short period"
  severity                   = "Medium"
  enabled                    = true

  query = <<-QUERY
    AzureDiagnostics
    | where ResourceProvider == "MICROSOFT.KEYVAULT"
    | where OperationName == "SecretGet"
    | summarize SecretReads = count() by CallerIPAddress, identity_claim_oid_s, bin(TimeGenerated, 5m)
    | where SecretReads > 20
  QUERY

  query_frequency = "PT5M"
  query_period    = "PT5M"

  trigger_operator  = "GreaterThan"
  trigger_threshold = 0

  tactics = ["Collection", "CredentialAccess"]
}
