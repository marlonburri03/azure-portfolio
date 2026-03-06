# ── Staging Environment ──────────────────────────────────────────────────────
# Production-like topology at lower cost. Used for integration testing,
# performance benchmarks, and pre-production validation.

environment = "staging"
location    = "uksouth"
owner       = "platform-engineering"
cost_center = "CC-1000-STG"

hub_vnet_address_space = ["10.50.0.0/16"]
firewall_subnet_prefix = "10.50.1.0/26"
bastion_subnet_prefix  = "10.50.2.0/26"
gateway_subnet_prefix  = "10.50.3.0/27"
firewall_sku_tier      = "Standard"

spoke_vnets = {
  corp-staging = {
    address_space       = ["10.51.0.0/16"]
    resource_group_name = "rg-spoke-corp-staging"
  }
  online-staging = {
    address_space       = ["10.52.0.0/16"]
    resource_group_name = "rg-spoke-online-staging"
  }
}

private_dns_zone_names = [
  "privatelink.blob.core.windows.net",
  "privatelink.database.windows.net",
  "privatelink.vaultcore.azure.net",
  "privatelink.azurewebsites.net",
]

allowed_locations                  = ["uksouth", "ukwest"]
root_management_group_display_name = "Contoso-Staging"

platform_identity_name = "id-platform-automation"
