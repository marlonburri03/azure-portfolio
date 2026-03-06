# ---------------------------------------------------------------------------
# storage.tf — Storage Account + blob containers
# ---------------------------------------------------------------------------
# The storage account serves two purposes:
# 1. Azure Functions runtime storage (leases, triggers state, deployment pkg)
# 2. Raw file uploads ingested by the blob_trigger function
#
# Public network access is disabled; all traffic flows through the Private
# Endpoint.  The Function App accesses storage via its Managed Identity and
# VNet integration.
# ---------------------------------------------------------------------------

resource "azurerm_storage_account" "main" {
  name                          = "st${var.project_name}${var.environment}"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  account_tier                  = "Standard"
  account_replication_type      = "ZRS" # Zone-redundant for production resilience
  min_tls_version               = "TLS1_2"
  public_network_access_enabled = false
  tags                          = local.common_tags

  # Immutable blobs not needed here, but we enable versioning for auditability.
  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 7
    }
  }
}

# Container for raw file uploads processed by the blob_trigger function.
resource "azurerm_storage_container" "raw_uploads" {
  name                  = "raw-uploads"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private" # No anonymous access
}

# Container used internally by the Functions runtime for trigger state.
resource "azurerm_storage_container" "function_releases" {
  name                  = "function-releases"
  storage_account_id    = azurerm_storage_account.main.id
  container_access_type = "private"
}

# ---------------------------------------------------------------------------
# Private Endpoint — ensures blob traffic stays on the Azure backbone.
# ---------------------------------------------------------------------------

resource "azurerm_private_endpoint" "storage_blob" {
  name                = "pe-blob-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "psc-blob"
    private_connection_resource_id = azurerm_storage_account.main.id
    is_manual_connection           = false
    subresource_names              = ["blob"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.zones["blob"].id]
  }
}

# ---------------------------------------------------------------------------
# RBAC — grant the Function App's Managed Identity access to blob storage.
# Using RBAC instead of connection strings avoids secret rotation overhead.
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "function_storage_blob_data_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}

resource "azurerm_role_assignment" "function_storage_account_contributor" {
  scope                = azurerm_storage_account.main.id
  role_definition_name = "Storage Account Contributor"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}
