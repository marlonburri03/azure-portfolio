# --------------------------------------------------------------------------
# Azure Managed Grafana — visualization layer that natively integrates
# with Azure Monitor and Log Analytics as datasources.
# --------------------------------------------------------------------------

resource "azurerm_dashboard_grafana" "main" {
  name                = "grafana-${local.name_prefix}-${local.region_abbr}"
  location            = azurerm_resource_group.observability.location
  resource_group_name = azurerm_resource_group.observability.name

  sku                           = var.grafana_sku
  zone_redundancy_enabled       = var.environment == "prod"
  api_key_enabled               = true
  deterministic_outbound_ip_enabled = var.environment == "prod"

  # Azure Monitor integration — this flag provisions the built-in Azure Monitor
  # datasource automatically, so Grafana can query metrics and logs on day one.
  azure_monitor_workspace_integrations {
    resource_id = azurerm_log_analytics_workspace.main.id
  }

  identity {
    type = "SystemAssigned"
  }

  tags = local.common_tags
}

# --- RBAC: Grafana needs Monitoring Reader on the subscription ---------------
# Without this, the Azure Monitor datasource cannot list or query resources.

resource "azurerm_role_assignment" "grafana_monitoring_reader" {
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  role_definition_name = "Monitoring Reader"
  principal_id         = azurerm_dashboard_grafana.main.identity[0].principal_id

  # Avoid destroy/recreate races when the Grafana identity changes.
  lifecycle {
    create_before_destroy = true
  }
}

# Log Analytics Reader lets Grafana run KQL queries against the workspace.
resource "azurerm_role_assignment" "grafana_law_reader" {
  scope                = azurerm_log_analytics_workspace.main.id
  role_definition_name = "Log Analytics Reader"
  principal_id         = azurerm_dashboard_grafana.main.identity[0].principal_id
}

# --- Admin role assignments --------------------------------------------------
# Grant specified AAD identities the Grafana Admin role so they can manage
# dashboards, datasources, and alerting inside the Grafana instance.

resource "azurerm_role_assignment" "grafana_admin" {
  for_each = toset(var.grafana_admin_object_ids)

  scope                = azurerm_dashboard_grafana.main.id
  role_definition_name = "Grafana Admin"
  principal_id         = each.value
}
