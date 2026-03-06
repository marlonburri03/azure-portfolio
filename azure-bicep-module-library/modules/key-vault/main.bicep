// ---------------------------------------------------------------------------
// Module: Key Vault
// Purpose: Deploy Azure Key Vault with RBAC authorization, private endpoint,
//          soft-delete, and purge protection — secrets never leave the network.
// ---------------------------------------------------------------------------

@description('Azure region for the Key Vault.')
param location string

@description('Name of the Key Vault. Must be globally unique.')
@minLength(3)
@maxLength(24)
param keyVaultName string

@description('Resource tags applied to every resource in this module.')
param tags object

@description('Object ID of the principal that receives Key Vault Administrator role.')
param adminObjectId string

@description('Enable purge protection — prevents permanent deletion during retention period.')
param enablePurgeProtection bool = true

@description('Soft-delete retention in days.')
@minValue(7)
@maxValue(90)
param softDeleteRetentionDays int = 90

// -- Private Endpoint parameters --
@description('Enable private endpoint for the Key Vault.')
param enablePrivateEndpoint bool = true

@description('Subnet resource ID for the private endpoint.')
param privateEndpointSubnetId string = ''

@description('Private DNS Zone resource ID for privatelink.vaultcore.azure.net.')
param privateDnsZoneId string = ''

// RBAC is the recommended authorization model — avoids vault access policies
// which are harder to audit and don't integrate with PIM.
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  tags: tags
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: softDeleteRetentionDays
    enablePurgeProtection: enablePurgeProtection
    // Deny public network access when private endpoint is enabled
    publicNetworkAccess: enablePrivateEndpoint ? 'Disabled' : 'Enabled'
    networkAcls: {
      defaultAction: enablePrivateEndpoint ? 'Deny' : 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Grant the admin principal full control via built-in Key Vault Administrator role.
resource adminRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVault.id, adminObjectId, 'Key Vault Administrator')
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '00482a5a-887f-4fb3-b363-3b7fe8e74483')
    principalId: adminObjectId
    principalType: 'ServicePrincipal'
  }
}

// Private endpoint keeps Key Vault traffic on the Azure backbone — no public internet exposure.
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = if (enablePrivateEndpoint && !empty(privateEndpointSubnetId)) {
  name: '${keyVaultName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${keyVaultName}-plsc'
        properties: {
          privateLinkServiceId: keyVault.id
          groupIds: ['vault']
        }
      }
    ]
  }
}

resource privateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-09-01' = if (enablePrivateEndpoint && !empty(privateDnsZoneId)) {
  name: 'default'
  parent: privateEndpoint
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'vault'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

@description('Resource ID of the Key Vault.')
output keyVaultId string = keyVault.id

@description('URI of the Key Vault.')
output keyVaultUri string = keyVault.properties.vaultUri

@description('Name of the Key Vault.')
output keyVaultName string = keyVault.name
