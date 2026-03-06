# ---------------------------------------------------------------------------
# Management Groups — CAF enterprise-scale hierarchy
#
# The tree mirrors Microsoft's reference architecture:
#   Root
#   ├── Platform
#   │   ├── Identity
#   │   ├── Management
#   │   └── Connectivity
#   ├── Landing Zones
#   │   ├── Corp
#   │   └── Online
#   ├── Sandbox
#   └── Decommissioned
#
# Placing subscriptions under the correct MG ensures they inherit the right
# set of policies and RBAC without per-subscription configuration.
# ---------------------------------------------------------------------------

resource "azurerm_management_group" "root" {
  display_name = var.root_display_name

  # Avoid name collisions across tenants by deriving a deterministic ID.
  name = lower(replace(var.root_display_name, " ", "-"))
}

# ── Level 1 — Platform & Workload Separation ────────────────────────────────

resource "azurerm_management_group" "platform" {
  display_name               = "Platform"
  parent_management_group_id = azurerm_management_group.root.id
  name                       = "${azurerm_management_group.root.name}-platform"
}

resource "azurerm_management_group" "landing_zones" {
  display_name               = "Landing Zones"
  parent_management_group_id = azurerm_management_group.root.id
  name                       = "${azurerm_management_group.root.name}-landing-zones"
}

resource "azurerm_management_group" "sandbox" {
  display_name               = "Sandbox"
  parent_management_group_id = azurerm_management_group.root.id
  name                       = "${azurerm_management_group.root.name}-sandbox"
}

resource "azurerm_management_group" "decommissioned" {
  display_name               = "Decommissioned"
  parent_management_group_id = azurerm_management_group.root.id
  name                       = "${azurerm_management_group.root.name}-decommissioned"
}

# ── Level 2 — Platform Children ─────────────────────────────────────────────

resource "azurerm_management_group" "identity" {
  display_name               = "Identity"
  parent_management_group_id = azurerm_management_group.platform.id
  name                       = "${azurerm_management_group.root.name}-identity"
}

resource "azurerm_management_group" "management" {
  display_name               = "Management"
  parent_management_group_id = azurerm_management_group.platform.id
  name                       = "${azurerm_management_group.root.name}-management"
}

resource "azurerm_management_group" "connectivity" {
  display_name               = "Connectivity"
  parent_management_group_id = azurerm_management_group.platform.id
  name                       = "${azurerm_management_group.root.name}-connectivity"
}

# ── Level 2 — Landing Zone Children ─────────────────────────────────────────

resource "azurerm_management_group" "corp" {
  display_name               = "Corp"
  parent_management_group_id = azurerm_management_group.landing_zones.id
  name                       = "${azurerm_management_group.root.name}-corp"
}

resource "azurerm_management_group" "online" {
  display_name               = "Online"
  parent_management_group_id = azurerm_management_group.landing_zones.id
  name                       = "${azurerm_management_group.root.name}-online"
}
