# ──────────────────────────────────────────────────────────────────────────────
# Azure Cost Governance — Outputs
# ──────────────────────────────────────────────────────────────────────────────

output "resource_group_name" {
  description = "Name of the resource group containing all cost-governance resources."
  value       = azurerm_resource_group.main.name
}

output "function_app_name" {
  description = "Name of the Function App running idle-resource detection."
  value       = azurerm_linux_function_app.idle_scanner.name
}

output "function_app_identity_principal_id" {
  description = "Principal ID of the Function App's system-assigned managed identity."
  value       = azurerm_linux_function_app.idle_scanner.identity[0].principal_id
}

output "logic_app_name" {
  description = "Name of the Logic App that dispatches cost reports."
  value       = azurerm_logic_app_workflow.cost_report.name
}

output "storage_account_name" {
  description = "Storage account used for Function App and report archival."
  value       = azurerm_storage_account.main.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault storing webhook secrets."
  value       = azurerm_key_vault.main.vault_uri
}

output "tag_policy_assignment_id" {
  description = "ID of the 'require tags' policy assignment."
  value       = azurerm_subscription_policy_assignment.require_tags.id
}

output "region_policy_assignment_id" {
  description = "ID of the 'allowed regions' policy assignment."
  value       = azurerm_subscription_policy_assignment.allowed_regions.id
}
