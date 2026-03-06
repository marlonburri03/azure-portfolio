// ──────────────────────────────────────────────────────────
// Module: Virtual Network with configurable subnets and NSGs
// ──────────────────────────────────────────────────────────

@description('Name of the virtual network.')
param name string

@description('Azure region for deployment.')
param location string

@description('Resource tags.')
param tags object

@description('VNet address space CIDR block.')
param addressPrefix string

@description('Array of subnet definitions.')
param subnets array

// DNS servers - empty means Azure-provided DNS
@description('Custom DNS servers. Leave empty for Azure-provided DNS.')
param dnsServers array = []

@description('Enable DDoS protection (recommended for production).')
param enableDdosProtection bool = false

resource vnet 'Microsoft.Network/virtualNetworks@2024-01-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [addressPrefix]
    }
    // Only set custom DNS if provided, otherwise Azure DNS is used
    dhcpOptions: !empty(dnsServers) ? { dnsServers: dnsServers } : null
    enableDdosProtection: enableDdosProtection
    subnets: [
      for (subnet, i) in subnets: {
        name: subnet.name
        properties: {
          addressPrefix: subnet.addressPrefix
          // Associate NSG for defense-in-depth
          networkSecurityGroup: contains(subnet, 'nsgId') && !empty(subnet.nsgId)
            ? { id: subnet.nsgId }
            : null
          // Delegations allow Azure services to manage the subnet
          delegations: contains(subnet, 'delegations')
            ? [
                for delegation in subnet.delegations: {
                  name: 'delegation-${replace(delegation, '/', '-')}'
                  properties: {
                    serviceName: delegation
                  }
                }
              ]
            : []
          // Private endpoints need this disabled for proper routing
          privateEndpointNetworkPolicies: contains(subnet, 'enablePrivateEndpoint') && subnet.enablePrivateEndpoint
            ? 'Disabled'
            : 'Enabled'
        }
      }
    ]
  }
}

// Diagnostic settings for network monitoring
resource diagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: '${name}-diag'
  scope: vnet
  properties: {
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

@description('The resource ID of the virtual network.')
output vnetId string = vnet.id

@description('The name of the virtual network.')
output vnetName string = vnet.name

@description('Array of subnet resource IDs in deployment order.')
output subnetIds array = [for (subnet, i) in subnets: vnet.properties.subnets[i].id]
