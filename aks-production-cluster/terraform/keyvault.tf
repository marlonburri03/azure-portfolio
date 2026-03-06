# --------------------------------------------------------------------------
# Azure Key Vault
# --------------------------------------------------------------------------

resource "azurerm_key_vault" "main" {
  name                = "kv-${var.project}-${var.environment}" # Max 24 chars
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = var.keyvault_sku
  tags                = local.tags

  # RBAC mode — no legacy access policies. All access is controlled via
  # Azure role assignments, which are auditable and centrally managed.
  enable_rbac_authorization = true

  # Soft delete protects against accidental deletion.
  # 90 days is the maximum retention for production compliance.
  soft_delete_retention_days = 90
  purge_protection_enabled   = true

  # Restrict network access — only the AKS subnet can reach Key Vault.
  network_acls {
    bypass                     = "AzureServices"
    default_action             = "Deny"
    virtual_network_subnet_ids = [azurerm_subnet.aks.id]
  }
}

# Grant the Terraform service principal admin access for initial secret seeding.
# In production this would be scoped to a break-glass admin group.
resource "azurerm_role_assignment" "deployer_keyvault_admin" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = data.azurerm_client_config.current.object_id
}

# --------------------------------------------------------------------------
# Private Endpoint — Key Vault accessible only over private network
# --------------------------------------------------------------------------

resource "azurerm_private_endpoint" "keyvault" {
  name                = "pe-kv-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-kv"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }
}

# --------------------------------------------------------------------------
# Private DNS Zone — resolves *.vault.azure.net to the private endpoint IP
# --------------------------------------------------------------------------

resource "azurerm_private_dns_zone" "keyvault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "keyvault" {
  name                  = "link-kv-vnet"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.keyvault.name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
}

resource "azurerm_private_dns_a_record" "keyvault" {
  name                = azurerm_key_vault.main.name
  zone_name           = azurerm_private_dns_zone.keyvault.name
  resource_group_name = azurerm_resource_group.main.name
  ttl                 = 300
  records             = [azurerm_private_endpoint.keyvault.private_service_connection[0].private_ip_address]
}
