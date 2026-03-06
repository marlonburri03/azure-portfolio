# =============================================================================
# Azure Firewall — centralized network security enforcement
#
# Zero Trust principle: Verify explicitly. All traffic — even east-west —
# must pass through the firewall where it is inspected, logged, and filtered
# by application and network rules.
# =============================================================================

# The Firewall needs a single public IP for management-plane operations and
# DNAT. This is the ONLY public IP in the entire deployment.
resource "azurerm_public_ip" "firewall" {
  name                = "pip-fw-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.common_tags
}

# -----------------------------------------------------------------------------
# Firewall Policy — rules are defined in a policy object so they can be
# versioned, audited, and reused across multiple firewalls if needed.
# -----------------------------------------------------------------------------

resource "azurerm_firewall_policy" "main" {
  name                = "fwpol-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = var.firewall_sku_tier
  tags                = local.common_tags

  # Enable threat intelligence filtering — blocks traffic to/from known
  # malicious IPs and domains using Microsoft's threat feed.
  threat_intelligence_mode = "Deny"

  dns {
    # Azure Firewall as DNS proxy ensures DNS queries are logged and can
    # resolve Private DNS zones for Private Endpoints.
    proxy_enabled = true
  }
}

# -----------------------------------------------------------------------------
# Firewall Instance
# -----------------------------------------------------------------------------

resource "azurerm_firewall" "main" {
  name                = "fw-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku_name            = "AZFW_VNet"
  sku_tier            = var.firewall_sku_tier
  firewall_policy_id  = azurerm_firewall_policy.main.id
  tags                = local.common_tags

  ip_configuration {
    name                 = "fw-ipconfig"
    subnet_id            = azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }
}

# -----------------------------------------------------------------------------
# Rule Collection Groups — ordered by priority
#
# Priority bands:
#   100-199  DNAT rules (inbound from internet)
#   200-299  Network rules (L4 allow/deny)
#   300-399  Application rules (L7 FQDN filtering)
# -----------------------------------------------------------------------------

resource "azurerm_firewall_policy_rule_collection_group" "main" {
  name               = "rcg-${local.name_prefix}"
  firewall_policy_id = azurerm_firewall_policy.main.id
  priority           = 100

  # --- DNAT Rules -----------------------------------------------------------
  # Translate inbound traffic from the Firewall's public IP to private backend
  # services. This is the only path from the internet to internal resources.
  nat_rule_collection {
    name     = "dnat-inbound"
    priority = 100
    action   = "Dnat"

    rule {
      name                = "dnat-https-to-app"
      protocols           = ["TCP"]
      source_addresses    = ["*"]
      destination_address = azurerm_public_ip.firewall.ip_address
      destination_ports   = ["443"]
      # Forward to the App Service private IP within the integration subnet
      translated_address = cidrhost(var.app_integration_subnet_prefix, 4)
      translated_port    = "443"
    }
  }

  # --- Network Rules ---------------------------------------------------------
  # L4 rules for protocols that can't be expressed as FQDNs (e.g. NTP, DNS).
  network_rule_collection {
    name     = "network-core"
    priority = 200
    action   = "Allow"

    # Allow spoke subnets to reach Azure DNS — required for Private DNS zone
    # resolution through the Firewall DNS proxy.
    rule {
      name                  = "allow-dns"
      protocols             = ["UDP", "TCP"]
      source_addresses      = var.spoke_vnet_address_space
      destination_addresses = ["168.63.129.16"]
      destination_ports     = ["53"]
    }

    # Allow NTP so VM clocks stay in sync — critical for Kerberos and TLS
    rule {
      name                  = "allow-ntp"
      protocols             = ["UDP"]
      source_addresses      = var.spoke_vnet_address_space
      destination_addresses = ["*"]
      destination_ports     = ["123"]
    }
  }

  # --- Application Rules (FQDN filtering) -----------------------------------
  # L7 rules inspect the SNI/Host header and enforce domain-level allowlists.
  application_rule_collection {
    name     = "app-outbound"
    priority = 300
    action   = "Allow"

    # Allow outbound to Microsoft services needed for App Service runtime,
    # diagnostics, and Azure AD authentication.
    rule {
      name = "allow-azure-services"
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses  = [var.app_integration_subnet_prefix]
      destination_fqdns = [
        "*.microsoft.com",
        "*.azure.com",
        "*.windows.net",
        "*.microsoftonline.com",
        "*.azure-api.net",
      ]
    }

    # Allow Ubuntu/Debian updates for any Linux VMs in the management subnet
    rule {
      name = "allow-os-updates"
      protocols {
        type = "Https"
        port = 443
      }
      protocols {
        type = "Http"
        port = 80
      }
      source_addresses  = [var.management_subnet_prefix]
      destination_fqdns = [
        "*.ubuntu.com",
        "*.debian.org",
        "packages.microsoft.com",
      ]
    }
  }
}

# -----------------------------------------------------------------------------
# Diagnostic Settings — send Firewall logs to Log Analytics for Sentinel
# correlation and compliance evidence.
# -----------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                       = "diag-fw-${local.name_prefix}"
  target_resource_id         = azurerm_firewall.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel.id

  enabled_log {
    category = "AzureFirewallApplicationRule"
  }

  enabled_log {
    category = "AzureFirewallNetworkRule"
  }

  enabled_log {
    category = "AzureFirewallDnsProxy"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
