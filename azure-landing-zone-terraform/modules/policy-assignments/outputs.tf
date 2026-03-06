output "policy_assignment_ids" {
  description = "Map of policy assignment names to their resource IDs."
  value = merge(
    {
      allowed_locations    = azurerm_management_group_policy_assignment.allowed_locations.id
      audit_unmanaged_disks = azurerm_management_group_policy_assignment.audit_unmanaged_disks.id
    },
    { for k, v in azurerm_management_group_policy_assignment.require_tag : "require_tag_${k}" => v.id },
    # Conditionally include the deny-public-IP assignment
    length(azurerm_management_group_policy_assignment.deny_public_ip) > 0
    ? { deny_public_ip = azurerm_management_group_policy_assignment.deny_public_ip[0].id }
    : {}
  )
}
