# ---------------------------------------------------------------------------
# Policy Assignments — guardrails scoped to the Landing Zones MG
#
# Policies enforce organisational standards automatically. They are assigned
# at the Landing Zones management group so every workload subscription
# inherits them without opt-in.
# ---------------------------------------------------------------------------

# ── Allowed Locations ────────────────────────────────────────────────────────
# Prevents resources from being deployed outside approved regions, reducing
# data-sovereignty risk and keeping latency predictable.

resource "azurerm_management_group_policy_assignment" "allowed_locations" {
  name                 = "Allowed-Locations"
  display_name         = "Restrict resource locations"
  description          = "Limits deployments to an approved set of Azure regions."
  management_group_id  = var.landing_zones_management_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/e56962a6-4747-49cd-b67b-bf8b01975c4c"

  parameters = jsonencode({
    listOfAllowedLocations = {
      value = var.allowed_locations
    }
  })
}

# ── Require Tags ─────────────────────────────────────────────────────────────
# Cost governance depends on accurate tagging. This policy denies resource
# creation when required tags are missing, catching mistakes at deploy time.

locals {
  required_tags = ["environment", "owner", "cost-center", "project"]
}

resource "azurerm_management_group_policy_assignment" "require_tag" {
  for_each = toset(local.required_tags)

  name                 = "Require-Tag-${each.key}"
  display_name         = "Require tag: ${each.key}"
  description          = "Denies resource creation when the '${each.key}' tag is missing."
  management_group_id  = var.landing_zones_management_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/871b6d14-10aa-478d-b590-94f262ecfa99"

  parameters = jsonencode({
    tagName = {
      value = each.key
    }
  })
}

# ── Audit VMs Without Managed Disks ─────────────────────────────────────────
# Unmanaged disks lack SLA-backed availability and encryption-at-rest by
# default. Auditing surfaces non-compliant VMs without blocking deployments.

resource "azurerm_management_group_policy_assignment" "audit_unmanaged_disks" {
  name                 = "Audit-Unmanaged-Disks"
  display_name         = "Audit VMs that do not use managed disks"
  description          = "Identifies virtual machines using unmanaged disks."
  management_group_id  = var.landing_zones_management_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/06a78e20-9358-41c9-923c-fb736d382a4d"
}

# ── Deny Public IP on NICs ───────────────────────────────────────────────────
# Workloads in Corp landing zones should route through the hub firewall.
# Blocking public IPs on NICs enforces this pattern. (Prod only — dev may need
# direct access for debugging.)

resource "azurerm_management_group_policy_assignment" "deny_public_ip" {
  count = var.environment == "prod" ? 1 : 0

  name                 = "Deny-PublicIP-NIC"
  display_name         = "Deny public IPs on network interfaces"
  description          = "Prevents public IP association on NICs to enforce hub-spoke egress."
  management_group_id  = var.landing_zones_management_group_id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/83a86a26-fd1f-447c-b59d-e51f44264114"
}
