# ---------------------------------------------------------------------------
# Root outputs — surface key resource identifiers for downstream consumers
# (other Terraform configs, CI/CD pipelines, documentation).
# ---------------------------------------------------------------------------

# ── Management Groups ────────────────────────────────────────────────────────

output "management_group_ids" {
  description = "Map of management group display names to their resource IDs."
  value       = module.management_groups.management_group_ids
}

# ── Policy ───────────────────────────────────────────────────────────────────

output "policy_assignment_ids" {
  description = "IDs of the policy assignments applied to the landing zones MG."
  value       = module.policy_assignments.policy_assignment_ids
}

# ── Connectivity ─────────────────────────────────────────────────────────────

output "hub_vnet_id" {
  description = "Resource ID of the hub virtual network."
  value       = module.connectivity.hub_vnet_id
}

output "hub_vnet_name" {
  description = "Name of the hub virtual network."
  value       = module.connectivity.hub_vnet_name
}

output "firewall_private_ip" {
  description = "Private IP address of the Azure Firewall (use as next-hop in UDRs)."
  value       = module.connectivity.firewall_private_ip
}

output "bastion_public_ip" {
  description = "Public IP of the Azure Bastion host."
  value       = module.connectivity.bastion_public_ip
}

output "private_dns_zone_ids" {
  description = "Map of Private DNS zone names to their resource IDs."
  value       = module.connectivity.private_dns_zone_ids
}

# ── Identity ─────────────────────────────────────────────────────────────────

output "platform_identity_id" {
  description = "Resource ID of the platform automation managed identity."
  value       = module.identity.managed_identity_id
}

output "platform_identity_client_id" {
  description = "Client ID of the platform automation managed identity."
  value       = module.identity.managed_identity_client_id
}
