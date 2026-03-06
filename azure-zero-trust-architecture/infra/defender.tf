# =============================================================================
# Microsoft Defender for Cloud — CSPM and JIT VM Access
#
# Zero Trust principle: Assume breach. Defender continuously assesses security
# posture, and JIT VM Access eliminates standing inbound admin ports.
# =============================================================================

# Enable Defender plans for the resource types in this deployment
resource "azurerm_security_center_subscription_pricing" "vms" {
  tier          = "Standard"
  resource_type = "VirtualMachines"
}

resource "azurerm_security_center_subscription_pricing" "app_services" {
  tier          = "Standard"
  resource_type = "AppServices"
}

resource "azurerm_security_center_subscription_pricing" "storage" {
  tier          = "Standard"
  resource_type = "StorageAccounts"
}

resource "azurerm_security_center_subscription_pricing" "keyvaults" {
  tier          = "Standard"
  resource_type = "KeyVaults"
}

# Send Defender alerts and recommendations to Log Analytics for Sentinel
resource "azurerm_security_center_workspace" "main" {
  scope        = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  workspace_id = azurerm_log_analytics_workspace.sentinel.id
}

# Auto-provision the Log Analytics agent so new VMs are automatically enrolled
resource "azurerm_security_center_auto_provisioning" "main" {
  auto_provision = "On"
}

# Enable continuous export of Defender alerts to Log Analytics
resource "azurerm_security_center_setting" "mcas" {
  setting_name = "MCAS"
  enabled      = true
}

resource "azurerm_security_center_setting" "sentinel" {
  setting_name = "Sentinel"
  enabled      = true
}

# -----------------------------------------------------------------------------
# JIT VM Access Policy
#
# JIT dynamically inserts NSG rules to allow RDP/SSH for a limited time
# window, only after the request is approved. This eliminates the need for
# permanently open management ports.
#
# NOTE: JIT policies are configured via the Azure REST API or portal because
# the azurerm provider does not have a native resource. The management NSG
# (see networking.tf) has DenyAllInbound as its baseline — JIT adds temporary
# Allow rules on top.
#
# Below is the recommended JIT configuration to apply via the portal or API:
#
# {
#   "virtualMachines": [{
#     "ports": [
#       { "number": 22,   "protocol": "TCP", "allowedSourceAddressPrefix": "*", "maxRequestAccessDuration": "PT3H" },
#       { "number": 3389, "protocol": "TCP", "allowedSourceAddressPrefix": "*", "maxRequestAccessDuration": "PT3H" }
#     ]
#   }]
# }
# -----------------------------------------------------------------------------
