output "hub_vnet_id" {
  description = "Resource ID of the hub virtual network."
  value       = azurerm_virtual_network.hub.id
}

output "hub_vnet_name" {
  description = "Name of the hub virtual network."
  value       = azurerm_virtual_network.hub.name
}

output "firewall_private_ip" {
  description = "Private IP of the Azure Firewall — use as next-hop in spoke UDRs."
  value       = azurerm_firewall.hub.ip_configuration[0].private_ip_address
}

output "bastion_public_ip" {
  description = "Public IP address of the Bastion host."
  value       = azurerm_public_ip.bastion.ip_address
}

output "private_dns_zone_ids" {
  description = "Map of Private DNS zone names to their resource IDs."
  value       = { for k, v in azurerm_private_dns_zone.zones : k => v.id }
}

output "spoke_vnet_ids" {
  description = "Map of spoke names to their VNet resource IDs."
  value       = { for k, v in azurerm_virtual_network.spokes : k => v.id }
}

output "connectivity_resource_group_id" {
  description = "Resource ID of the connectivity resource group."
  value       = azurerm_resource_group.connectivity.id
}
