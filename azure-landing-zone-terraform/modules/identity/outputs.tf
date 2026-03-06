output "managed_identity_id" {
  description = "Resource ID of the platform automation managed identity."
  value       = azurerm_user_assigned_identity.platform.id
}

output "managed_identity_client_id" {
  description = "Client (application) ID of the managed identity — use in workload configuration."
  value       = azurerm_user_assigned_identity.platform.client_id
}

output "managed_identity_principal_id" {
  description = "Object (principal) ID of the managed identity — use in RBAC assignments."
  value       = azurerm_user_assigned_identity.platform.principal_id
}
