# ---------------------------------------------------------------------------
# Connectivity Module — Hub VNet, Azure Firewall, Bastion, Private DNS, Peering
#
# This module builds the centralised networking layer. All spokes peer to the
# hub, and Azure Firewall provides a single egress point with full L4/L7
# inspection. Bastion gives secure, browser-based access to VMs without
# exposing RDP/SSH on public IPs.
# ---------------------------------------------------------------------------

# ── Resource Group ───────────────────────────────────────────────────────────

resource "azurerm_resource_group" "connectivity" {
  name     = "rg-connectivity-${var.environment}"
  location = var.location
  tags     = var.common_tags
}

# ── Hub Virtual Network ─────────────────────────────────────────────────────

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-${var.environment}"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
  address_space       = var.hub_vnet_address_space
  tags                = var.common_tags
}

# Azure Firewall requires a dedicated subnet named exactly "AzureFirewallSubnet".
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.connectivity.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.firewall_subnet_prefix]
}

# Bastion requires a dedicated subnet named exactly "AzureBastionSubnet".
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.connectivity.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.bastion_subnet_prefix]
}

resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.connectivity.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.gateway_subnet_prefix]
}

# ── Azure Firewall ───────────────────────────────────────────────────────────

resource "azurerm_public_ip" "firewall" {
  name                = "pip-fw-${var.environment}"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
  allocation_method   = "Static"
  sku                 = "Standard" # Required for Azure Firewall
  tags                = var.common_tags
}

resource "azurerm_firewall_policy" "hub" {
  name                = "fwpol-hub-${var.environment}"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
  sku                 = var.firewall_sku_tier

  # DNS proxy enables FQDN-based network rules and Private DNS resolution
  # through the firewall for spoke workloads.
  dns {
    proxy_enabled = true
  }

  tags = var.common_tags
}

resource "azurerm_firewall" "hub" {
  name                = "fw-hub-${var.environment}"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku_tier
  firewall_policy_id  = azurerm_firewall_policy.hub.id

  ip_configuration {
    name                 = "fw-ipconfig"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  tags = var.common_tags
}

# ── Azure Bastion ────────────────────────────────────────────────────────────

resource "azurerm_public_ip" "bastion" {
  name                = "pip-bastion-${var.environment}"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.common_tags
}

resource "azurerm_bastion_host" "hub" {
  name                = "bas-hub-${var.environment}"
  location            = azurerm_resource_group.connectivity.location
  resource_group_name = azurerm_resource_group.connectivity.name
  sku                 = "Standard"

  # Native client support lets engineers use az network bastion ssh/rdp from
  # their terminals — much faster than the portal experience.
  tunneling_enabled    = true
  copy_paste_enabled   = true
  file_copy_enabled    = true
  ip_connect_enabled   = true

  ip_configuration {
    name                 = "bastion-ipconfig"
    subnet_id            = azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  tags = var.common_tags
}

# ── Private DNS Zones ────────────────────────────────────────────────────────
# Private DNS zones enable name resolution for Azure Private Endpoints.
# Linking them to the hub VNet means spokes (which peer to the hub) can
# resolve private endpoint FQDNs without extra configuration.

resource "azurerm_private_dns_zone" "zones" {
  for_each = toset(var.private_dns_zone_names)

  name                = each.value
  resource_group_name = azurerm_resource_group.connectivity.name
  tags                = var.common_tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "hub_links" {
  for_each = azurerm_private_dns_zone.zones

  name                  = "link-hub-${replace(each.key, ".", "-")}"
  resource_group_name   = azurerm_resource_group.connectivity.name
  private_dns_zone_name = each.value.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false # Only enable for the zone matching the VNet's domain

  depends_on = [azurerm_private_dns_zone.zones]
}

# ── VNet Peering (Hub ↔ Spokes) ─────────────────────────────────────────────
# Peering is bidirectional — we create one link from hub → spoke and one from
# spoke → hub. Gateway transit is enabled on the hub side so spokes can use
# the VPN/ExpressRoute gateway without needing their own.

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  for_each = var.spoke_vnets

  name                         = "peer-hub-to-${each.key}"
  resource_group_name          = azurerm_resource_group.connectivity.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spokes[each.key].id
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true  # Spokes share the hub's gateway
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  for_each = var.spoke_vnets

  name                         = "peer-${each.key}-to-hub"
  resource_group_name          = azurerm_resource_group.spokes[each.key].name
  virtual_network_name         = azurerm_virtual_network.spokes[each.key].name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_forwarded_traffic      = true
  use_remote_gateways          = false # Set to true when a gateway is deployed
  allow_virtual_network_access = true
}

# Spoke resource groups — each spoke gets its own RG for clear RBAC boundaries.
resource "azurerm_resource_group" "spokes" {
  for_each = var.spoke_vnets

  name     = each.value.resource_group_name
  location = var.location
  tags     = var.common_tags
}

# Spoke VNets — created alongside the hub so peering can reference them.
resource "azurerm_virtual_network" "spokes" {
  for_each = var.spoke_vnets

  name                = "vnet-${each.key}-${var.environment}"
  location            = azurerm_resource_group.spokes[each.key].location
  resource_group_name = azurerm_resource_group.spokes[each.key].name
  address_space       = each.value.address_space
  tags                = var.common_tags
}
