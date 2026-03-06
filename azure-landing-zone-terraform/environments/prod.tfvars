# ── Production Environment ───────────────────────────────────────────────────
# Full-scale deployment with Premium Firewall, all Private DNS zones, and
# strict policy enforcement (deny public IPs on NICs).

environment = "prod"
location    = "uksouth"
owner       = "platform-engineering"
cost_center = "CC-1000-PROD"

hub_vnet_address_space = ["10.0.0.0/16"]
firewall_subnet_prefix = "10.0.1.0/26"
bastion_subnet_prefix  = "10.0.2.0/26"
gateway_subnet_prefix  = "10.0.3.0/27"
firewall_sku_tier      = "Premium" # TLS inspection, IDPS, URL filtering

spoke_vnets = {
  corp-prod = {
    address_space       = ["10.1.0.0/16"]
    resource_group_name = "rg-spoke-corp-prod"
  }
  online-prod = {
    address_space       = ["10.2.0.0/16"]
    resource_group_name = "rg-spoke-online-prod"
  }
}

private_dns_zone_names = [
  "privatelink.blob.core.windows.net",
  "privatelink.database.windows.net",
  "privatelink.vaultcore.azure.net",
  "privatelink.azurewebsites.net",
  "privatelink.azurecr.io",
  "privatelink.redis.cache.windows.net",
]

allowed_locations                  = ["uksouth", "ukwest"]
root_management_group_display_name = "Contoso"

platform_identity_name = "id-platform-automation"
