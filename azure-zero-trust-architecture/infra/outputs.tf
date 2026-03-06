output "resource_group_name" {
  description = "Name of the resource group containing all Zero Trust resources"
  value       = azurerm_resource_group.main.name
}

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------

output "hub_vnet_id" {
  description = "Resource ID of the hub VNet"
  value       = azurerm_virtual_network.hub.id
}

output "spoke_vnet_id" {
  description = "Resource ID of the spoke VNet"
  value       = azurerm_virtual_network.spoke.id
}

output "firewall_private_ip" {
  description = "Private IP of the Azure Firewall — used as the default route for spoke traffic"
  value       = azurerm_firewall.main.ip_configuration[0].private_ip_address
}

# -----------------------------------------------------------------------------
# Application
# -----------------------------------------------------------------------------

output "app_service_default_hostname" {
  description = "Default hostname of the App Service (only reachable through Firewall / Private Endpoint)"
  value       = azurerm_linux_web_app.main.default_hostname
}

output "app_service_identity_principal_id" {
  description = "Principal ID of the App Service managed identity for RBAC assignments"
  value       = azurerm_linux_web_app.main.identity[0].principal_id
}

# -----------------------------------------------------------------------------
# Security
# -----------------------------------------------------------------------------

output "key_vault_uri" {
  description = "URI of the Key Vault (accessible only via Private Endpoint)"
  value       = azurerm_key_vault.main.vault_uri
}

output "log_analytics_workspace_id" {
  description = "Workspace ID for Log Analytics / Sentinel — used for diagnostic settings"
  value       = azurerm_log_analytics_workspace.sentinel.workspace_id
}

output "sentinel_workspace_name" {
  description = "Name of the Log Analytics workspace backing Sentinel"
  value       = azurerm_log_analytics_workspace.sentinel.name
}
