# --------------------------------------------------------------------------
# AKS Cluster Managed Identity
# --------------------------------------------------------------------------

# User-assigned identity for the AKS control plane.
# Preferred over system-assigned because it survives cluster recreation
# and can be pre-granted permissions before the cluster exists.
resource "azurerm_user_assigned_identity" "aks" {
  name                = "id-aks-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

# AKS needs Network Contributor on the VNet to join nodes to the subnet
# and to configure load balancer rules.
resource "azurerm_role_assignment" "aks_network_contributor" {
  scope                = azurerm_virtual_network.main.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

# AGIC add-on needs Contributor on the Application Gateway to manage
# backends, listeners, and routing rules dynamically.
resource "azurerm_role_assignment" "aks_agw_contributor" {
  scope                = azurerm_application_gateway.main.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_kubernetes_cluster.main.ingress_application_gateway[0].ingress_application_gateway_identity[0].object_id
}

# --------------------------------------------------------------------------
# Workload Identity for Application Pods
# --------------------------------------------------------------------------

# This identity is federated with the AKS OIDC issuer so pods can
# authenticate to Azure services (Key Vault, Storage, SQL) without secrets.
resource "azurerm_user_assigned_identity" "workload" {
  name                = "id-workload-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

# Federated credential binds a Kubernetes ServiceAccount to this Azure identity.
# The triple (issuer, namespace, service-account-name) uniquely identifies the workload.
resource "azurerm_federated_identity_credential" "workload" {
  name                = "fic-sample-app"
  resource_group_name = azurerm_resource_group.main.name
  parent_id           = azurerm_user_assigned_identity.workload.id
  audience            = ["api://AzureADTokenExchange"]
  issuer              = azurerm_kubernetes_cluster.main.oidc_issuer_url
  subject             = "system:serviceaccount:sample-app:sample-app-sa"
}

# Grant the workload identity read access to Key Vault secrets.
# This is the least-privilege role for applications that only consume secrets.
resource "azurerm_role_assignment" "workload_keyvault_reader" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.workload.principal_id
}
