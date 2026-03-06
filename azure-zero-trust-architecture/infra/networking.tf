# =============================================================================
# Networking — Hub-Spoke topology with micro-segmented subnets
#
# Zero Trust principle: Assume breach. Segment the network so a compromised
# workload cannot move laterally. Every subnet has an NSG. No public IPs
# are assigned to any resource.
# =============================================================================

# -----------------------------------------------------------------------------
# Hub VNet — hosts Azure Firewall and management/jumpbox resources
# -----------------------------------------------------------------------------

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-hub-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.hub_vnet_address_space
  tags                = local.common_tags
}

# Azure Firewall requires a subnet named exactly "AzureFirewallSubnet"
resource "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.firewall_subnet_prefix]
}

resource "azurerm_subnet" "management" {
  name                 = "snet-management-${local.name_prefix}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.management_subnet_prefix]
}

# -----------------------------------------------------------------------------
# Spoke VNet — hosts application workloads, private endpoints, and data tier
# -----------------------------------------------------------------------------

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-spoke-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = var.spoke_vnet_address_space
  tags                = local.common_tags
}

# Delegated to App Service for regional VNet integration
resource "azurerm_subnet" "app_integration" {
  name                 = "snet-app-${local.name_prefix}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.app_integration_subnet_prefix]

  # Delegation is required for App Service VNet integration — it grants the
  # platform permission to inject NICs into this subnet.
  delegation {
    name = "app-service-delegation"
    service_delegation {
      name = "Microsoft.Web/serverFarms"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action",
      ]
    }
  }
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-pe-${local.name_prefix}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.private_endpoint_subnet_prefix]

  # Private Endpoints don't support NSG by default; this opt-in flag enables it
  # so we can enforce least-privilege even on PE traffic.
  private_endpoint_network_policies = "Enabled"
}

resource "azurerm_subnet" "data" {
  name                 = "snet-data-${local.name_prefix}"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.data_subnet_prefix]
}

# -----------------------------------------------------------------------------
# Hub ↔ Spoke Peering — enables transit through the Firewall
# -----------------------------------------------------------------------------

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                         = "peer-hub-to-spoke"
  resource_group_name          = azurerm_resource_group.main.name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke.id
  allow_forwarded_traffic      = true
  allow_gateway_transit        = true
  allow_virtual_network_access = true
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                         = "peer-spoke-to-hub"
  resource_group_name          = azurerm_resource_group.main.name
  virtual_network_name         = azurerm_virtual_network.spoke.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_forwarded_traffic      = true
  use_remote_gateways          = false
  allow_virtual_network_access = true
}

# -----------------------------------------------------------------------------
# Network Security Groups — explicit deny-all + allowlist model
# -----------------------------------------------------------------------------

resource "azurerm_network_security_group" "management" {
  name                = "nsg-management-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  # Deny all inbound by default — JIT VM Access will insert time-limited
  # allow rules dynamically via Microsoft Defender for Cloud.
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "app" {
  name                = "nsg-app-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  # Allow inbound only from the Azure Firewall subnet — all external traffic
  # must traverse the firewall before reaching the application tier.
  security_rule {
    name                       = "AllowFirewallInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.firewall_subnet_prefix
    destination_address_prefix = var.app_integration_subnet_prefix
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "private_endpoints" {
  name                = "nsg-pe-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  # Only the app integration subnet can reach Private Endpoints — prevents
  # direct data exfiltration from other subnets.
  security_rule {
    name                       = "AllowAppSubnetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.app_integration_subnet_prefix
    destination_address_prefix = var.private_endpoint_subnet_prefix
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_security_group" "data" {
  name                = "nsg-data-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  security_rule {
    name                       = "AllowAppSubnetInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = var.app_integration_subnet_prefix
    destination_address_prefix = var.data_subnet_prefix
  }

  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# -----------------------------------------------------------------------------
# NSG ↔ Subnet Associations
# -----------------------------------------------------------------------------

resource "azurerm_subnet_network_security_group_association" "management" {
  subnet_id                 = azurerm_subnet.management.id
  network_security_group_id = azurerm_network_security_group.management.id
}

resource "azurerm_subnet_network_security_group_association" "app" {
  subnet_id                 = azurerm_subnet.app_integration.id
  network_security_group_id = azurerm_network_security_group.app.id
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
}

resource "azurerm_subnet_network_security_group_association" "data" {
  subnet_id                 = azurerm_subnet.data.id
  network_security_group_id = azurerm_network_security_group.data.id
}

# -----------------------------------------------------------------------------
# NSG Flow Logs — visibility into all traffic for threat hunting and auditing
# -----------------------------------------------------------------------------

resource "azurerm_network_watcher" "main" {
  name                = "nw-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags
}

# Flow logs are stored in the same storage account we create in storage.tf.
# Traffic Analytics feeds into Log Analytics for Sentinel correlation.
resource "azurerm_network_watcher_flow_log" "app_nsg" {
  name                 = "flowlog-app-${local.name_prefix}"
  network_watcher_name = azurerm_network_watcher.main.name
  resource_group_name  = azurerm_resource_group.main.name
  network_security_group_id = azurerm_network_security_group.app.id
  storage_account_id        = azurerm_storage_account.main.id
  enabled                   = true

  retention_policy {
    enabled = true
    days    = 90
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.sentinel.workspace_id
    workspace_region      = azurerm_log_analytics_workspace.sentinel.location
    workspace_resource_id = azurerm_log_analytics_workspace.sentinel.id
    interval_in_minutes   = 10
  }
}

resource "azurerm_network_watcher_flow_log" "pe_nsg" {
  name                 = "flowlog-pe-${local.name_prefix}"
  network_watcher_name = azurerm_network_watcher.main.name
  resource_group_name  = azurerm_resource_group.main.name
  network_security_group_id = azurerm_network_security_group.private_endpoints.id
  storage_account_id        = azurerm_storage_account.main.id
  enabled                   = true

  retention_policy {
    enabled = true
    days    = 90
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.sentinel.workspace_id
    workspace_region      = azurerm_log_analytics_workspace.sentinel.location
    workspace_resource_id = azurerm_log_analytics_workspace.sentinel.id
    interval_in_minutes   = 10
  }
}

# -----------------------------------------------------------------------------
# Route Table — force all spoke egress through the Azure Firewall
# Without this, spoke subnets would bypass the firewall for internet-bound traffic.
# -----------------------------------------------------------------------------

resource "azurerm_route_table" "spoke" {
  name                          = "rt-spoke-${local.name_prefix}"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  tags                          = local.common_tags

  # Disable BGP propagation to prevent routes that bypass the firewall
  bgp_route_propagation_enabled = false

  route {
    name                   = "default-via-firewall"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "app" {
  subnet_id      = azurerm_subnet.app_integration.id
  route_table_id = azurerm_route_table.spoke.id
}

resource "azurerm_subnet_route_table_association" "data" {
  subnet_id      = azurerm_subnet.data.id
  route_table_id = azurerm_route_table.spoke.id
}
