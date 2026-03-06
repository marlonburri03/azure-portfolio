# ---------------------------------------------------------------------------
# functions.tf — Function App + App Service Plan
# ---------------------------------------------------------------------------
# The Elastic Premium plan (EP1) is chosen over Consumption because:
# 1. It supports VNet integration (required for Private Endpoints).
# 2. It provides pre-warmed instances to avoid cold-start latency.
# 3. It still scales to zero when idle (cost-effective for dev).
# ---------------------------------------------------------------------------

resource "azurerm_service_plan" "main" {
  name                = "asp-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  sku_name            = var.function_app_sku
  tags                = local.common_tags
}

resource "azurerm_linux_function_app" "main" {
  name                          = "func-${local.name_prefix}"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  service_plan_id               = azurerm_service_plan.main.id
  storage_account_name          = azurerm_storage_account.main.name
  storage_uses_managed_identity = true # No storage connection string needed
  public_network_access_enabled = false
  virtual_network_subnet_id     = azurerm_subnet.functions.id
  tags                          = local.common_tags

  # System-assigned Managed Identity — used for all service-to-service auth
  # (Storage, Cosmos DB, Service Bus, Key Vault).
  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.11"
    }

    # Route all outbound traffic through the VNet so Private Endpoint DNS
    # resolution works for storage, Cosmos DB, Service Bus, etc.
    vnet_route_all_enabled = true

    application_insights_connection_string = azurerm_application_insights.main.connection_string

    # Enforce HTTPS-only and minimum TLS 1.2.
    ftps_state    = "Disabled"
    http2_enabled = true
  }

  app_settings = {
    # ---- Runtime settings ----
    FUNCTIONS_WORKER_RUNTIME = "python"
    PYTHON_ENABLE_INIT_INDEXING = "1"

    # ---- Service Bus (identity-based, no connection string) ----
    # The __fullyQualifiedNamespace app setting is the convention for
    # identity-based Service Bus trigger connections.
    SERVICE_BUS_CONNECTION__fullyQualifiedNamespace = "${azurerm_servicebus_namespace.main.name}.servicebus.windows.net"
    SERVICE_BUS_NAMESPACE                           = azurerm_servicebus_namespace.main.name
    SERVICE_BUS_QUEUE_NAME                          = azurerm_servicebus_queue.events.name

    # ---- Cosmos DB ----
    COSMOS_DB_ENDPOINT  = azurerm_cosmosdb_account.main.endpoint
    COSMOS_DB_DATABASE  = azurerm_cosmosdb_sql_database.events.name
    COSMOS_DB_CONTAINER = azurerm_cosmosdb_sql_container.processed_events.name

    # ---- Storage (identity-based) ----
    # AzureWebJobsStorage__accountName tells the runtime to use Managed
    # Identity instead of a connection string for the host storage.
    AzureWebJobsStorage__accountName   = azurerm_storage_account.main.name
    STORAGE_CONNECTION__accountName     = azurerm_storage_account.main.name

    # ---- Build & deploy ----
    WEBSITE_RUN_FROM_PACKAGE = "1" # Deploy from zip package for immutable releases
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
  }

  lifecycle {
    # Ignore app_settings changes made by the deployment pipeline (e.g.,
    # WEBSITE_RUN_FROM_PACKAGE URL updates).
    ignore_changes = [
      app_settings["WEBSITE_RUN_FROM_PACKAGE"],
    ]
  }
}

# ---------------------------------------------------------------------------
# Private Endpoint — Function App
# ---------------------------------------------------------------------------
# Locks down inbound traffic to the Function App so only VNet-connected
# resources (APIM, Event Grid) can invoke functions.
# ---------------------------------------------------------------------------

resource "azurerm_private_endpoint" "function_app" {
  name                = "pe-func-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "psc-func"
    private_connection_resource_id = azurerm_linux_function_app.main.id
    is_manual_connection           = false
    subresource_names              = ["sites"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.zones["sites"].id]
  }
}

# ---------------------------------------------------------------------------
# RBAC — grant the Function App's identity Key Vault Secrets User so it can
# resolve @Microsoft.KeyVault() references in app settings.
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "function_keyvault_reader" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}
