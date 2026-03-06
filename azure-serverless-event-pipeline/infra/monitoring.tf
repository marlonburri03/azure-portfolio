# ---------------------------------------------------------------------------
# monitoring.tf — Application Insights + Log Analytics Workspace
# ---------------------------------------------------------------------------
# Application Insights provides distributed tracing, live metrics, and
# alerting for the Function App.  It sends data to a Log Analytics workspace
# for long-term retention and KQL-based querying.
# ---------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 90 # 90 days balances cost with investigation needs
  tags                = local.common_tags
}

resource "azurerm_application_insights" "main" {
  name                = "ai-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.main.id
  application_type    = "web"
  tags                = local.common_tags

  # Sampling reduces cost in high-throughput scenarios while preserving
  # representative traces.  Adjust via daily_data_cap_in_gb if needed.
  sampling_percentage = 100 # Start at 100% for dev; reduce in prod
}

# ---------------------------------------------------------------------------
# Diagnostic Settings — stream Azure service logs into Log Analytics
# ---------------------------------------------------------------------------
# Capturing platform logs (e.g., Function App HTTP logs, Service Bus metrics)
# alongside Application Insights telemetry gives a single pane of glass.
# ---------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "function_app" {
  name                       = "diag-func"
  target_resource_id         = azurerm_linux_function_app.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "FunctionAppLogs"
  }

  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "service_bus" {
  name                       = "diag-sb"
  target_resource_id         = azurerm_servicebus_namespace.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "OperationalLogs"
  }

  metric {
    category = "AllMetrics"
  }
}

resource "azurerm_monitor_diagnostic_setting" "cosmos_db" {
  name                       = "diag-cosmos"
  target_resource_id         = azurerm_cosmosdb_account.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "DataPlaneRequests"
  }

  enabled_log {
    category = "QueryRuntimeStatistics"
  }

  metric {
    category = "AllMetrics"
  }
}

# ---------------------------------------------------------------------------
# Alerts — critical issues that need immediate attention
# ---------------------------------------------------------------------------

resource "azurerm_monitor_metric_alert" "function_errors" {
  name                = "alert-func-errors-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_linux_function_app.main.id]
  description         = "Fires when Function App error rate exceeds threshold."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = local.common_tags

  criteria {
    metric_namespace = "Microsoft.Web/sites"
    metric_name      = "Http5xx"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 10
  }
}

resource "azurerm_monitor_metric_alert" "servicebus_deadletter" {
  name                = "alert-sb-dlq-${local.name_prefix}"
  resource_group_name = azurerm_resource_group.main.name
  scopes              = [azurerm_servicebus_namespace.main.id]
  description         = "Fires when messages land in the dead-letter queue."
  severity            = 2
  frequency           = "PT5M"
  window_size         = "PT15M"
  tags                = local.common_tags

  criteria {
    metric_namespace = "Microsoft.ServiceBus/namespaces"
    metric_name      = "DeadletteredMessages"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 0
  }
}
