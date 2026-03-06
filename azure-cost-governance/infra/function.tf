# ──────────────────────────────────────────────────────────────────────────────
# Azure Cost Governance — Function App (Idle Resource Scanner)
# ──────────────────────────────────────────────────────────────────────────────
# Hosts find_idle_resources.py and generate_cost_report.py as HTTP-triggered
# Azure Functions.  Uses a system-assigned Managed Identity for all Azure
# SDK calls — no secrets required.

# ── App Service Plan (Consumption) ─────────────────────────────────────────
# Consumption plan means we pay only when the functions execute, which
# aligns with the cost-optimisation theme of this project.

resource "azurerm_service_plan" "functions" {
  name                = "plan-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  os_type             = "Linux"
  sku_name            = "Y1" # Consumption tier

  tags = local.tags
}

# ── Linux Function App ─────────────────────────────────────────────────────

resource "azurerm_linux_function_app" "idle_scanner" {
  name                = "func-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  service_plan_id     = azurerm_service_plan.functions.id

  storage_account_name       = azurerm_storage_account.main.name
  storage_account_access_key = azurerm_storage_account.main.primary_access_key

  # System-assigned identity is used by find_idle_resources.py via
  # DefaultAzureCredential — no connection strings or passwords.
  identity {
    type = "SystemAssigned"
  }

  site_config {
    application_stack {
      python_version = "3.11"
    }

    # Application Insights connection is set via app_settings below.
    application_insights_connection_string = azurerm_application_insights.main.connection_string
  }

  app_settings = {
    # Tell the Azure SDK which subscription to scan.
    "AZURE_SUBSCRIPTION_ID" = var.subscription_id

    # Required for Python consumption functions on Linux.
    "AzureWebJobsFeatureFlags" = "EnableWorkerIndexing"
  }

  tags = local.tags
}

# ── Application Insights (telemetry for Function invocations) ─────────────

resource "azurerm_application_insights" "main" {
  name                = "appi-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  application_type    = "web"

  tags = local.tags
}

# ── RBAC — give the Function App read access across the subscription ──────
# Reader is the minimum role needed to enumerate resources and read cost
# data.  This follows least-privilege: the scanner never mutates resources.

resource "azurerm_role_assignment" "function_reader" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azurerm_linux_function_app.idle_scanner.identity[0].principal_id

  # Avoids a race condition where the identity isn't propagated to AAD yet.
  depends_on = [azurerm_linux_function_app.idle_scanner]
}

# Cost Management Reader is a separate role that grants access to the
# Cost Management APIs.  Reader alone is not sufficient.
resource "azurerm_role_assignment" "function_cost_reader" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Cost Management Reader"
  principal_id         = azurerm_linux_function_app.idle_scanner.identity[0].principal_id

  depends_on = [azurerm_linux_function_app.idle_scanner]
}
