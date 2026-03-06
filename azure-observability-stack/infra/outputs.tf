output "resource_group_name" {
  description = "Name of the observability resource group"
  value       = azurerm_resource_group.observability.name
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics Workspace (use in diagnostic settings)"
  value       = azurerm_log_analytics_workspace.main.id
}

output "log_analytics_workspace_key" {
  description = "Primary shared key for the Log Analytics Workspace"
  value       = azurerm_log_analytics_workspace.main.primary_shared_key
  sensitive   = true
}

output "log_analytics_customer_id" {
  description = "Workspace (customer) ID — used by agents to identify the workspace"
  value       = azurerm_log_analytics_workspace.main.workspace_id
}

output "grafana_endpoint" {
  description = "URL of the Azure Managed Grafana instance"
  value       = azurerm_dashboard_grafana.main.endpoint
}

output "grafana_principal_id" {
  description = "Managed identity principal ID of the Grafana instance (use for additional RBAC)"
  value       = azurerm_dashboard_grafana.main.identity[0].principal_id
}

output "action_group_critical_id" {
  description = "Resource ID of the critical-severity action group"
  value       = azurerm_monitor_action_group.critical.id
}

output "action_group_warning_id" {
  description = "Resource ID of the warning-severity action group"
  value       = azurerm_monitor_action_group.warning.id
}
