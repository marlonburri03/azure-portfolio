// ──────────────────────────────────────────────────────────
// Module: Network Security Group with common security rules
// ──────────────────────────────────────────────────────────

@description('Name of the NSG.')
param name string

@description('Azure region for deployment.')
param location string

@description('Resource tags.')
param tags object

@description('Additional custom security rules to merge with defaults.')
param customRules array = []

resource nsg 'Microsoft.Network/networkSecurityGroups@2024-01-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    securityRules: union(defaultRules, customRules)
  }
}

// Baseline rules that align with Azure security best practices
var defaultRules = [
  {
    // Block all inbound internet traffic by default (deny-all approach)
    name: 'DenyAllInbound'
    properties: {
      priority: 4096
      direction: 'Inbound'
      access: 'Deny'
      protocol: '*'
      sourceAddressPrefix: '*'
      sourcePortRange: '*'
      destinationAddressPrefix: '*'
      destinationPortRange: '*'
    }
  }
  {
    // Allow HTTPS inbound for web workloads
    name: 'AllowHTTPS'
    properties: {
      priority: 100
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourceAddressPrefix: '*'
      sourcePortRange: '*'
      destinationAddressPrefix: 'VirtualNetwork'
      destinationPortRange: '443'
    }
  }
  {
    // Allow Azure Load Balancer health probes
    name: 'AllowAzureLoadBalancer'
    properties: {
      priority: 110
      direction: 'Inbound'
      access: 'Allow'
      protocol: '*'
      sourceAddressPrefix: 'AzureLoadBalancer'
      sourcePortRange: '*'
      destinationAddressPrefix: '*'
      destinationPortRange: '*'
    }
  }
  {
    // Allow intra-VNet traffic for service-to-service communication
    name: 'AllowVNetInbound'
    properties: {
      priority: 200
      direction: 'Inbound'
      access: 'Allow'
      protocol: '*'
      sourceAddressPrefix: 'VirtualNetwork'
      sourcePortRange: '*'
      destinationAddressPrefix: 'VirtualNetwork'
      destinationPortRange: '*'
    }
  }
]

@description('The resource ID of the NSG.')
output nsgId string = nsg.id

@description('The name of the NSG.')
output nsgName string = nsg.name
