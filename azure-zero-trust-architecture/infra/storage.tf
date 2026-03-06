# =============================================================================
# Storage Account — blob storage with zero public exposure
# =============================================================================

resource "azurerm_storage_account" "main" {
  name                          = "st${replace(local.name_prefix, "-", "")}01"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  account_tier                  = "Standard"
  account_replication_type      = "GRS"
  tags                          = local.common_tags
  min_tls_version               = "TLS1_2"
  public_network_access_enabled = false
  allow_nested_items_to_be_public = false

  # Disable shared key access — force Azure AD authentication only
  shared_access_key_enabled = false

  identity {
    type = "SystemAssigned"
  }

  blob_properties {
    delete_retention_policy { days = 30 }
    container_delete_retention_policy { days = 30 }
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }
}

resource "azurerm_role_assignment" "app_storage_blob" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_web_app.main.identity[0].principal_id
}

resource "azurerm_monitor_diagnostic_setting" "storage" {
  name                       = "diag-st-${local.name_prefix}"
  target_resource_id         = "${azurerm_storage_account.main.id}/blobServices/default"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel.id

  enabled_log { category = "StorageRead" }
  enabled_log { category = "StorageWrite" }
  enabled_log { category = "StorageDelete" }

  metric {
    category = "Transaction"
    enabled  = true
  }
}
