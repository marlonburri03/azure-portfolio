# ---------------------------------------------------------------------------
# Identity Module — Managed Identities and RBAC
#
# Platform automation (CI/CD, policy remediation, monitoring) uses a
# User-Assigned Managed Identity instead of service principal secrets.
# This eliminates credential rotation overhead and reduces the blast radius
# of a credential leak to zero — there is no secret to leak.
# ---------------------------------------------------------------------------

resource "azurerm_resource_group" "identity" {
  name     = "rg-identity-${var.environment}"
  location = var.location
  tags     = var.common_tags
}

# ── User-Assigned Managed Identity ───────────────────────────────────────────
# A single identity for platform-level automation. Workload teams get their
# own identities scoped to their subscriptions.

resource "azurerm_user_assigned_identity" "platform" {
  name                = "${var.platform_identity_name}-${var.environment}"
  location            = azurerm_resource_group.identity.location
  resource_group_name = azurerm_resource_group.identity.name
  tags                = var.common_tags
}

# ── RBAC — Reader at subscription scope ─────────────────────────────────────
# Grants the platform identity read access across the subscription. More
# privileged roles (Contributor, Owner) should be assigned at narrower scopes
# (resource group or resource level) following least-privilege principles.

data "azurerm_subscription" "current" {}

resource "azurerm_role_assignment" "platform_reader" {
  scope                = data.azurerm_subscription.current.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.platform.principal_id

  # Avoid recreating the assignment if the identity is replaced.
  lifecycle {
    ignore_changes = [principal_id]
  }
}

# ── RBAC — Network Contributor on connectivity RG ────────────────────────────
# The platform identity needs to manage peering and route tables. Scoping
# the role to the connectivity resource group avoids over-privileging.
# The resource group ID is passed in from the connectivity module output to
# create an explicit dependency.

resource "azurerm_role_assignment" "platform_network_contributor" {
  scope                = var.connectivity_resource_group_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.platform.principal_id

  lifecycle {
    ignore_changes = [principal_id]
  }
}
