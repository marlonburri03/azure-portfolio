# -----------------------------------------------------------------------------
# Resource Group
# -----------------------------------------------------------------------------

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.common_tags
}

# -----------------------------------------------------------------------------
# Module references — each file below contributes resources into this group.
# This file acts as the composition root and wires shared values.
# See networking.tf, firewall.tf, app-service.tf, etc. for resource definitions.
# -----------------------------------------------------------------------------
