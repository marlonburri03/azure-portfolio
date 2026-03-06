output "management_group_ids" {
  description = "Map of management group display names to resource IDs."
  value = {
    root             = azurerm_management_group.root.id
    platform         = azurerm_management_group.platform.id
    identity         = azurerm_management_group.identity.id
    management       = azurerm_management_group.management.id
    connectivity     = azurerm_management_group.connectivity.id
    landing_zones    = azurerm_management_group.landing_zones.id
    corp             = azurerm_management_group.corp.id
    online           = azurerm_management_group.online.id
    sandbox          = azurerm_management_group.sandbox.id
    decommissioned   = azurerm_management_group.decommissioned.id
  }
}

output "landing_zones_management_group_id" {
  description = "Resource ID of the Landing Zones management group — policy assignments target this scope."
  value       = azurerm_management_group.landing_zones.id
}
