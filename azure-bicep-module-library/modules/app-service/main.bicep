// ──────────────────────────────────────────────────────────
// Module: App Service with VNet integration and managed identity
// ──────────────────────────────────────────────────────────

@description('Name of the App Service.')
param name string

@description('Azure region for deployment.')
param location string

@description('Resource tags.')
param tags object

@description('App Service Plan SKU name.')
@allowed(['B1', 'B2', 'B3', 'S1', 'S2', 'S3', 'P1v3', 'P2v3', 'P3v3'])
param skuName string = 'P1v3'

@description('Subnet ID for VNet integration (must have Microsoft.Web/serverFarms delegation).')
param subnetId string

@description('Runtime stack (e.g., DOTNETCORE|8.0, NODE|20-lts, PYTHON|3.12).')
param linuxFxVersion string = 'DOTNETCORE|8.0'

@description('Enable Always On to prevent cold starts.')
param alwaysOn bool = true

@description('Minimum TLS version for HTTPS enforcement.')
param minTlsVersion string = '1.2'

// App Service Plan - the compute that backs the App Service
resource plan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: 'plan-${name}'
  location: location
  tags: tags
  kind: 'linux'
  properties: {
    reserved: true // Required for Linux App Service Plans
  }
  sku: {
    name: skuName
  }
}

resource app 'Microsoft.Web/sites@2023-12-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    // System-assigned identity for passwordless auth to Azure services
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true // Force HTTPS for all traffic
    virtualNetworkSubnetId: subnetId
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      alwaysOn: alwaysOn
      minTlsVersion: minTlsVersion
      ftpsState: 'Disabled' // FTPS is a security risk
      http20Enabled: true
      // VNet route all ensures all outbound traffic goes through VNet
      vnetRouteAllEnabled: true
      healthCheckPath: '/health'
    }
  }
}

// Staging slot for zero-downtime deployments
resource stagingSlot 'Microsoft.Web/sites/slots@2023-12-01' = {
  parent: app
  name: 'staging'
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: plan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: linuxFxVersion
      alwaysOn: alwaysOn
      minTlsVersion: minTlsVersion
      ftpsState: 'Disabled'
      http20Enabled: true
      autoSwapSlotName: 'production'
    }
  }
}

@description('Default hostname of the App Service.')
output defaultHostname string = app.properties.defaultHostName

@description('Resource ID of the App Service.')
output appId string = app.id

@description('Principal ID of the App Service managed identity.')
output identityPrincipalId string = app.identity.principalId

@description('Resource ID of the App Service Plan.')
output planId string = plan.id
