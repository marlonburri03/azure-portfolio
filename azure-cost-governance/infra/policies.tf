# ──────────────────────────────────────────────────────────────────────────────
# Azure Cost Governance — Azure Policy Definitions & Assignments
# ──────────────────────────────────────────────────────────────────────────────
# Policies enforce organisational standards at the subscription level so
# non-compliant resources are flagged (or denied) before they cause
# cost-tracking blind spots.

# ── Require Tags Policy ────────────────────────────────────────────────────
# Ensures that every resource carries the mandatory tags defined in
# var.required_tags. Without tags, cost reports cannot attribute spend to
# teams or cost centres.

resource "azurerm_policy_definition" "require_tags" {
  name         = "require-mandatory-tags-${var.environment}"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Require mandatory tags (${var.environment})"
  description  = "Deny resource creation when one or more required tags are missing."

  # The policy rule is authored in JSON so it can be version-controlled
  # alongside the Terraform config and reused in the policies/ directory.
  policy_rule = file("${path.module}/../policies/require-tags.json")

  parameters = jsonencode({
    requiredTags = {
      type = "Array"
      metadata = {
        description = "List of tag names that must be present."
        displayName = "Required Tags"
      }
      defaultValue = var.required_tags
    }
  })
}

resource "azurerm_subscription_policy_assignment" "require_tags" {
  name                 = "assign-require-tags-${var.environment}"
  policy_definition_id = azurerm_policy_definition.require_tags.id
  subscription_id      = "/subscriptions/${var.subscription_id}"
  display_name         = "Require mandatory tags (${var.environment})"
  description          = "Denies resources that lack mandatory cost-tracking tags."
  enforce              = true

  parameters = jsonencode({
    requiredTags = { value = var.required_tags }
  })
}

# ── Allowed Regions Policy ─────────────────────────────────────────────────
# Restricts resource creation to a known set of regions. This prevents
# accidental deployments in expensive or non-compliant geographies.

resource "azurerm_policy_definition" "allowed_regions" {
  name         = "allowed-regions-${var.environment}"
  policy_type  = "Custom"
  mode         = "Indexed"
  display_name = "Allowed regions (${var.environment})"
  description  = "Deny resource creation outside the approved region list."

  policy_rule = file("${path.module}/../policies/allowed-regions.json")

  parameters = jsonencode({
    allowedLocations = {
      type = "Array"
      metadata = {
        description = "Azure regions where resources are permitted."
        displayName = "Allowed Locations"
      }
      defaultValue = var.allowed_locations
    }
  })
}

resource "azurerm_subscription_policy_assignment" "allowed_regions" {
  name                 = "assign-allowed-regions-${var.environment}"
  policy_definition_id = azurerm_policy_definition.allowed_regions.id
  subscription_id      = "/subscriptions/${var.subscription_id}"
  display_name         = "Allowed regions (${var.environment})"
  description          = "Denies resource creation outside approved regions."
  enforce              = true

  parameters = jsonencode({
    allowedLocations = { value = var.allowed_locations }
  })
}
