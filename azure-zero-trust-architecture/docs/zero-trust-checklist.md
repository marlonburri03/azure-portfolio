# Zero Trust Implementation Checklist

Use this checklist to validate every layer of the Zero Trust deployment.

## Identity & Access

- [ ] Azure AD Conditional Access policies deployed (see `conditional-access-policies.md`)
- [ ] MFA enforced for all users with no exceptions (except break-glass accounts)
- [ ] Legacy authentication protocols blocked
- [ ] Emergency access accounts created and excluded from CA policies
- [ ] All service-to-service authentication uses Managed Identities (no stored credentials)
- [ ] Key Vault uses RBAC authorization (not access policies)
- [ ] Least-privilege RBAC assignments verified — no Owner/Contributor at subscription scope

## Network Security

- [ ] Hub-spoke VNet topology deployed with peering
- [ ] All spoke egress routed through Azure Firewall (UDR 0.0.0.0/0)
- [ ] Azure Firewall threat intelligence set to **Deny** mode
- [ ] NSGs applied to every non-firewall subnet with explicit deny-all baseline
- [ ] NSG flow logs enabled with Traffic Analytics
- [ ] No public IPs assigned to any workload resource
- [ ] Private Endpoints created for Key Vault, Storage, and App Service
- [ ] Private DNS zones linked to both hub and spoke VNets
- [ ] Azure Firewall DNS proxy enabled for Private Endpoint resolution

## Application Security

- [ ] App Service public network access disabled
- [ ] App Service VNet integration configured (all outbound via spoke VNet)
- [ ] `vnet_route_all_enabled` set to true
- [ ] Minimum TLS version set to 1.2
- [ ] HTTPS-only enforced
- [ ] IP restrictions allow traffic only from Firewall subnet
- [ ] Application Insights connected to Log Analytics workspace

## Data Protection

- [ ] Storage account public access disabled
- [ ] Storage shared key access disabled (Azure AD auth only)
- [ ] Storage soft-delete enabled (blob + container)
- [ ] Key Vault purge protection enabled
- [ ] Key Vault soft-delete retention set to 90 days
- [ ] All data-at-rest encrypted (Azure default + customer-managed keys if required)

## Threat Detection & Response

- [ ] Microsoft Defender for Cloud enabled (Standard tier) for VMs, App Services, Storage, Key Vault
- [ ] JIT VM Access configured for management subnet VMs
- [ ] Microsoft Sentinel onboarded to Log Analytics workspace
- [ ] Sentinel data connectors enabled: Azure AD, Defender for Cloud, Azure Activity
- [ ] Sentinel analytics rules configured for brute-force and mass secret access
- [ ] Firewall diagnostic logs sent to Log Analytics
- [ ] App Service audit/HTTP logs sent to Log Analytics

## Governance & Compliance

- [ ] All resources tagged with Project, Environment, ManagedBy, SecurityModel
- [ ] Terraform remote state stored in encrypted Azure Storage with RBAC
- [ ] CI/CD uses OIDC authentication (no stored secrets)
- [ ] Resource group deletion protection enabled
- [ ] BGP route propagation disabled on spoke route tables
