# --------------------------------------------------------------------------
# Outputs — consumed by CI/CD pipelines and downstream Terraform configs
# --------------------------------------------------------------------------

output "resource_group_name" {
  description = "Name of the resource group containing all AKS resources."
  value       = azurerm_resource_group.main.name
}

output "aks_cluster_name" {
  description = "Name of the AKS cluster."
  value       = azurerm_kubernetes_cluster.main.name
}

output "aks_cluster_id" {
  description = "Resource ID of the AKS cluster."
  value       = azurerm_kubernetes_cluster.main.id
}

output "aks_oidc_issuer_url" {
  description = "OIDC issuer URL for Workload Identity federation."
  value       = azurerm_kubernetes_cluster.main.oidc_issuer_url
}

output "kubelet_identity_object_id" {
  description = "Object ID of the kubelet managed identity (used for ACR pull)."
  value       = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

output "workload_identity_client_id" {
  description = "Client ID of the workload managed identity. Set as azure.workload.identity/client-id annotation on ServiceAccounts."
  value       = azurerm_user_assigned_identity.workload.client_id
}

output "key_vault_name" {
  description = "Name of the Key Vault instance."
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault (used in SecretProviderClass)."
  value       = azurerm_key_vault.main.vault_uri
}

output "application_gateway_public_ip" {
  description = "Public IP address of the Application Gateway for DNS records."
  value       = azurerm_public_ip.appgw.ip_address
}

output "vnet_id" {
  description = "Resource ID of the virtual network."
  value       = azurerm_virtual_network.main.id
}

output "log_analytics_workspace_id" {
  description = "Resource ID of the Log Analytics workspace."
  value       = azurerm_log_analytics_workspace.main.id
}
