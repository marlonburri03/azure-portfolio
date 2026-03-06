# ---------------------------------------------------------------------------
# outputs.tf — Values surfaced after `terraform apply`
# ---------------------------------------------------------------------------
# These outputs are consumed by the GitHub Actions deployment workflow and
# by developers who need to interact with the deployed resources.
# ---------------------------------------------------------------------------

output "resource_group_name" {
  description = "Name of the resource group containing all resources."
  value       = azurerm_resource_group.main.name
}

output "function_app_name" {
  description = "Name of the deployed Function App."
  value       = azurerm_linux_function_app.main.name
}

output "function_app_default_hostname" {
  description = "Default hostname of the Function App (private)."
  value       = azurerm_linux_function_app.main.default_hostname
}

output "storage_account_name" {
  description = "Name of the Storage Account."
  value       = azurerm_storage_account.main.name
}

output "cosmos_db_endpoint" {
  description = "Cosmos DB account endpoint."
  value       = azurerm_cosmosdb_account.main.endpoint
}

output "service_bus_namespace" {
  description = "Fully qualified Service Bus namespace."
  value       = "${azurerm_servicebus_namespace.main.name}.servicebus.windows.net"
}

output "event_grid_topic_endpoint" {
  description = "Event Grid topic endpoint URL."
  value       = azurerm_eventgrid_topic.main.endpoint
}

output "apim_gateway_url" {
  description = "API Management gateway URL."
  value       = azurerm_api_management.main.gateway_url
}

output "application_insights_connection_string" {
  description = "Application Insights connection string."
  value       = azurerm_application_insights.main.connection_string
  sensitive   = true
}

output "key_vault_uri" {
  description = "Key Vault URI."
  value       = azurerm_key_vault.main.vault_uri
}
