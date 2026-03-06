# ---------------------------------------------------------------------------
# Root module — orchestrates all child modules.
#
# Each module maps to a CAF design area:
#   management-groups  → Governance hierarchy
#   policy-assignments → Guardrails & compliance
#   connectivity       → Hub networking & shared services
#   identity           → Managed identities & RBAC
# ---------------------------------------------------------------------------

locals {
  # Consistent tags propagated to every resource via module inputs.
  common_tags = merge(var.default_tags, {
    environment = var.environment
    owner       = var.owner
    cost-center = var.cost_center
    project     = "azure-landing-zone"
    managed-by  = "terraform"
  })
}

# ── Management Groups ────────────────────────────────────────────────────────

module "management_groups" {
  source = "./modules/management-groups"

  root_display_name = var.root_management_group_display_name
  tenant_id         = var.tenant_id
}

# ── Policy Assignments ───────────────────────────────────────────────────────

module "policy_assignments" {
  source = "./modules/policy-assignments"

  # Policies are scoped to the landing-zones management group so workload
  # subscriptions inherit guardrails automatically.
  landing_zones_management_group_id = module.management_groups.landing_zones_management_group_id
  allowed_locations                 = var.allowed_locations
  environment                       = var.environment
  common_tags                       = local.common_tags
}

# ── Connectivity (Hub & Spoke) ───────────────────────────────────────────────

module "connectivity" {
  source = "./modules/connectivity"

  location               = var.location
  environment            = var.environment
  hub_vnet_address_space = var.hub_vnet_address_space
  firewall_subnet_prefix = var.firewall_subnet_prefix
  bastion_subnet_prefix  = var.bastion_subnet_prefix
  gateway_subnet_prefix  = var.gateway_subnet_prefix
  spoke_vnets            = var.spoke_vnets
  private_dns_zone_names = var.private_dns_zone_names
  firewall_sku_tier      = var.firewall_sku_tier
  common_tags            = local.common_tags
}

# ── Identity ─────────────────────────────────────────────────────────────────

module "identity" {
  source = "./modules/identity"

  location               = var.location
  environment            = var.environment
  platform_identity_name = var.platform_identity_name
  common_tags            = local.common_tags
}
