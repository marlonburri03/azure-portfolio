// ---------------------------------------------------------------------------
// Module: Storage Account
// Purpose: Deploy Azure Storage with private endpoint, lifecycle management,
//          blob versioning, and soft-delete — secure defaults for production.
// ---------------------------------------------------------------------------

@description('Azure region for the Storage Account.')
param location string

@description('Name of the Storage Account. Must be globally unique, 3-24 lowercase alphanumeric.')
@minLength(3)
@maxLength(24)
param storageAccountName string

@description('Resource tags applied to every resource in this module.')
param tags object

@description('Storage account SKU.')
@allowed(['Standard_LRS', 'Standard_GRS', 'Standard_ZRS', 'Standard_RAGRS'])
param skuName string = 'Standard_ZRS'

@description('Enable blob versioning for point-in-time recovery.')
param enableVersioning bool = true

@description('Blob soft-delete retention in days.')
@minValue(1)
@maxValue(365)
param blobSoftDeleteDays int = 30

@description('Container soft-delete retention in days.')
@minValue(1)
@maxValue(365)
param containerSoftDeleteDays int = 30

@description('Number of days after which blobs move to Cool tier. 0 to disable.')
param moveToCoolAfterDays int = 30

@description('Number of days after which blobs are deleted. 0 to disable.')
param deleteAfterDays int = 365

// -- Private Endpoint parameters --
@description('Enable private endpoint for the Storage Account.')
param enablePrivateEndpoint bool = true

@description('Subnet resource ID for the private endpoint.')
param privateEndpointSubnetId string = ''

@description('Private DNS Zone resource ID for privatelink.blob.core.windows.net.')
param privateDnsZoneId string = ''

// ZRS gives zone redundancy without the cost of GRS — good default for production.
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: false // Force AAD auth — shared keys are a security risk
    publicNetworkAccess: enablePrivateEndpoint ? 'Disabled' : 'Enabled'
    networkAcls: {
      defaultAction: enablePrivateEndpoint ? 'Deny' : 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Blob service configuration — versioning and soft-delete protect against accidental deletion.
resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-01-01' = {
  parent: storageAccount
  name: 'default'
  properties: {
    isVersioningEnabled: enableVersioning
    deleteRetentionPolicy: {
      enabled: true
      days: blobSoftDeleteDays
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: containerSoftDeleteDays
    }
  }
}

// Lifecycle management reduces cost by tiering old blobs automatically.
resource lifecyclePolicy 'Microsoft.Storage/storageAccounts/managementPolicies@2023-01-01' = if (moveToCoolAfterDays > 0 || deleteAfterDays > 0) {
  parent: storageAccount
  name: 'default'
  properties: {
    policy: {
      rules: [
        {
          name: 'lifecycle-rule'
          enabled: true
          type: 'Lifecycle'
          definition: {
            filters: {
              blobTypes: ['blockBlob']
            }
            actions: {
              baseBlob: union(
                moveToCoolAfterDays > 0 ? { tierToCool: { daysAfterModificationGreaterThan: moveToCoolAfterDays } } : {},
                deleteAfterDays > 0 ? { delete: { daysAfterModificationGreaterThan: deleteAfterDays } } : {}
              )
            }
          }
        }
      ]
    }
  }
}

// Private endpoint ensures blob traffic stays on the Azure backbone.
resource privateEndpoint 'Microsoft.Network/privateEndpoints@2023-09-01' = if (enablePrivateEndpoint && !empty(privateEndpointSubnetId)) {
  name: '${storageAccountName}-pe'
  location: location
  tags: tags
  properties: {
    subnet: {
      id: privateEndpointSubnetId
    }
    privateLinkServiceConnections: [
      {
        name: '${storageAccountName}-plsc'
        properties: {
          privateLinkServiceId: storageAccount.id
          groupIds: ['blob']
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
        name: 'blob'
        properties: {
          privateDnsZoneId: privateDnsZoneId
        }
      }
    ]
  }
}

@description('Resource ID of the Storage Account.')
output storageAccountId string = storageAccount.id

@description('Name of the Storage Account.')
output storageAccountName string = storageAccount.name

@description('Primary blob endpoint.')
output primaryBlobEndpoint string = storageAccount.properties.primaryEndpoints.blob
