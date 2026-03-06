# ── Dev Environment ──────────────────────────────────────────────────────────
# Smaller SKUs, relaxed policies, single-region. Optimised for cost while
# keeping the architecture identical to production.

environment = "dev"
location    = "uksouth"
owner       = "platform-engineering"
cost_center = "CC-1000-DEV"

# Networking — smaller address spaces are fine for dev workloads.
hub_vnet_address_space = ["10.100.0.0/16"]
firewall_subnet_prefix = "10.100.1.0/26"
bastion_subnet_prefix  = "10.100.2.0/26"
gateway_subnet_prefix  = "10.100.3.0/27"
firewall_sku_tier      = "Standard"

spoke_vnets = {
  corp-dev = {
    address_space       = ["10.101.0.0/16"]
    resource_group_name = "rg-spoke-corp-dev"
  }
}

private_dns_zone_names = [
  "privatelink.blob.core.windows.net",
  "privatelink.database.windows.net",
  "privatelink.vaultcore.azure.net",
]

# Governance
allowed_locations                  = ["uksouth", "ukwest"]
root_management_group_display_name = "Contoso-Dev"

# Identity
platform_identity_name = "id-platform-automation"
