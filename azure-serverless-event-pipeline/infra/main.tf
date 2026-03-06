# ---------------------------------------------------------------------------
# main.tf — Core resources: Resource Group, VNet, Key Vault, Private DNS
# ---------------------------------------------------------------------------
# This file provisions shared foundational resources that other modules depend
# on.  The naming convention is:  <resource-prefix>-<project>-<environment>
# ---------------------------------------------------------------------------

locals {
  # Consistent naming and tagging across every resource.
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = merge(var.tags, {
    project     = var.project_name
    environment = var.environment
    managed_by  = "terraform"
  })
}

# Retrieve the current Azure client metadata so we can reference the tenant
# and object IDs without hardcoding them.
data "azurerm_client_config" "current" {}

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.common_tags
}

# ---------------------------------------------------------------------------
# Virtual Network & Subnets
# ---------------------------------------------------------------------------
# All data-plane traffic stays on the private backbone; only the APIM gateway
# has a public endpoint (which itself can be locked down with NSGs/WAF).
# ---------------------------------------------------------------------------

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.vnet_address_space
  tags                = local.common_tags
}

# Dedicated subnet for Function App VNet integration.
resource "azurerm_subnet" "functions" {
  name                 = "snet-functions"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_functions_prefix]

  # Required delegation for Function App VNet integration.
  delegation {
    name = "functions-delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action",
      ]
    }
  }
}

# Dedicated subnet for Private Endpoints — no delegations allowed here.
resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.subnet_private_endpoints_prefix]
}

# ---------------------------------------------------------------------------
# Private DNS Zones
# ---------------------------------------------------------------------------
# Each Azure service that supports Private Endpoints needs its own DNS zone so
# that name resolution from within the VNet resolves to the private IP.
# ---------------------------------------------------------------------------

locals {
  private_dns_zones = {
    blob     = "privatelink.blob.core.windows.net"
    cosmos   = "privatelink.documents.azure.com"
    servicebus = "privatelink.servicebus.windows.net"
    keyvault = "privatelink.vaultcore.azure.net"
    sites    = "privatelink.azurewebsites.net"
  }
}

resource "azurerm_private_dns_zone" "zones" {
  for_each            = local.private_dns_zones
  name                = each.value
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "links" {
  for_each              = local.private_dns_zones
  name                  = "link-${each.key}"
  resource_group_name   = azurerm_resource_group.main.name
  private_dns_zone_name = azurerm_private_dns_zone.zones[each.key].name
  virtual_network_id    = azurerm_virtual_network.main.id
  registration_enabled  = false
  tags                  = local.common_tags
}

# ---------------------------------------------------------------------------
# Key Vault
# ---------------------------------------------------------------------------
# Central secret store.  No secrets are hardcoded anywhere — Function App
# settings reference Key Vault via @Microsoft.KeyVault() syntax.
# ---------------------------------------------------------------------------

resource "azurerm_key_vault" "main" {
  name                        = "kv-${local.name_prefix}"
  location                    = azurerm_resource_group.main.location
  resource_group_name         = azurerm_resource_group.main.name
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  sku_name                    = "standard"
  purge_protection_enabled    = true
  soft_delete_retention_days  = 30
  enable_rbac_authorization   = true # Use Azure RBAC instead of vault access policies
  tags                        = local.common_tags

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices" # Allow trusted Azure services (e.g., Function App)
  }
}

# Private Endpoint for Key Vault
resource "azurerm_private_endpoint" "keyvault" {
  name                = "pe-kv-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "psc-kv"
    private_connection_resource_id = azurerm_key_vault.main.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.zones["keyvault"].id]
  }
}
