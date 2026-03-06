# --------------------------------------------------------------------------
# Log Analytics Workspace — the central data plane for all observability data.
# Every Azure resource ships diagnostics here via Diagnostic Settings.
# --------------------------------------------------------------------------

resource "azurerm_log_analytics_workspace" "main" {
  name                = "law-${local.name_prefix}-${local.region_abbr}"
  location            = azurerm_resource_group.observability.location
  resource_group_name = azurerm_resource_group.observability.name

  sku               = var.log_analytics_sku
  retention_in_days = var.log_retention_days

  # Daily cap prevents runaway costs from noisy workloads in non-prod.
  # Production should rely on alerts instead of hard caps.
  daily_quota_gb = var.environment == "prod" ? -1 : 5

  # internet_ingestion and query both enabled — required for Grafana and
  # external tooling to query the workspace over public endpoints.
  internet_ingestion_enabled = true
  internet_query_enabled     = true

  tags = local.common_tags
}

# --- Solutions ---------------------------------------------------------------
# Solutions extend the workspace with curated dashboards and collection rules.
# ContainerInsights is critical for AKS monitoring; VMInsights for VMs.

resource "azurerm_log_analytics_solution" "container_insights" {
  solution_name         = "ContainerInsights"
  location              = azurerm_resource_group.observability.location
  resource_group_name   = azurerm_resource_group.observability.name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }

  tags = local.common_tags
}

resource "azurerm_log_analytics_solution" "vm_insights" {
  solution_name         = "VMInsights"
  location              = azurerm_resource_group.observability.location
  resource_group_name   = azurerm_resource_group.observability.name
  workspace_resource_id = azurerm_log_analytics_workspace.main.id
  workspace_name        = azurerm_log_analytics_workspace.main.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/VMInsights"
  }

  tags = local.common_tags
}

# --- Diagnostic Settings Example ---------------------------------------------
# This shows how to wire a resource's diagnostics into the workspace.
# In practice, each team module would create its own diagnostic setting.

# resource "azurerm_monitor_diagnostic_setting" "example" {
#   name                       = "diag-to-law"
#   target_resource_id         = azurerm_kubernetes_cluster.example.id
#   log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
#
#   enabled_log { category = "kube-apiserver" }
#   enabled_log { category = "kube-controller-manager" }
#   enabled_log { category = "kube-scheduler" }
#   enabled_log { category = "cluster-autoscaler" }
#
#   metric {
#     category = "AllMetrics"
#     enabled  = true
#   }
# }
