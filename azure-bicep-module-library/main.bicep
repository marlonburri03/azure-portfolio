// ──────────────────────────────────────────────────────────────
// Orchestrator: composes all modules into a complete environment
// ──────────────────────────────────────────────────────────────

targetScope = 'subscription'

@description('The Azure region for all resources.')
param location string

@description('Environment name used for naming and tagging.')
@allowed(['dev', 'staging', 'prod'])
param environmentName string

@description('Base name prefix for all resources.')
@minLength(2)
@maxLength(10)
param projectName string

@description('Tags applied to every resource.')
param tags object = {
  environment: environmentName
  project: projectName
  managedBy: 'bicep'
}

@description('VNet address space CIDR.')
param vnetAddressPrefix string = '10.0.0.0/16'

@description('AKS node count.')
param aksNodeCount int = 3

@description('AKS node VM size.')
param aksNodeVmSize string = 'Standard_D4s_v5'

@description('App Service SKU name.')
param appServiceSkuName string = 'P1v3'

@description('Key Vault admin principal ID for RBAC.')
param keyVaultAdminPrincipalId string

// ── Resource Group ──────────────────────────────────────────
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${projectName}-${environmentName}'
  location: location
  tags: tags
}

// ── NSG (deployed before VNet so it can be associated) ──────
module nsg 'modules/nsg/main.bicep' = {
  scope: rg
  name: 'nsg-deployment'
  params: {
    name: 'nsg-${projectName}-${environmentName}'
    location: location
    tags: tags
  }
}

// ── Virtual Network ─────────────────────────────────────────
module vnet 'modules/vnet/main.bicep' = {
  scope: rg
  name: 'vnet-deployment'
  params: {
    name: 'vnet-${projectName}-${environmentName}'
    location: location
    tags: tags
    addressPrefix: vnetAddressPrefix
    subnets: [
      {
        name: 'snet-aks'
        addressPrefix: cidrSubnet(vnetAddressPrefix, 20, 0)
        nsgId: nsg.outputs.nsgId
      }
      {
        name: 'snet-appservice'
        addressPrefix: cidrSubnet(vnetAddressPrefix, 24, 16)
        nsgId: nsg.outputs.nsgId
        delegations: [
          'Microsoft.Web/serverFarms'
        ]
      }
      {
        name: 'snet-private-endpoints'
        addressPrefix: cidrSubnet(vnetAddressPrefix, 24, 17)
        nsgId: nsg.outputs.nsgId
      }
    ]
  }
}

// ── Storage Account ─────────────────────────────────────────
module storage 'modules/storage/main.bicep' = {
  scope: rg
  name: 'storage-deployment'
  params: {
    name: replace('st${projectName}${environmentName}', '-', '')
    location: location
    tags: tags
    privateEndpointSubnetId: vnet.outputs.subnetIds[2]
    vnetId: vnet.outputs.vnetId
  }
}

// ── Key Vault ───────────────────────────────────────────────
module keyVault 'modules/key-vault/main.bicep' = {
  scope: rg
  name: 'keyvault-deployment'
  params: {
    name: 'kv-${projectName}-${environmentName}'
    location: location
    tags: tags
    adminPrincipalId: keyVaultAdminPrincipalId
    privateEndpointSubnetId: vnet.outputs.subnetIds[2]
    vnetId: vnet.outputs.vnetId
  }
}

// ── AKS Cluster ─────────────────────────────────────────────
module aks 'modules/aks/main.bicep' = {
  scope: rg
  name: 'aks-deployment'
  params: {
    name: 'aks-${projectName}-${environmentName}'
    location: location
    tags: tags
    subnetId: vnet.outputs.subnetIds[0]
    nodeCount: aksNodeCount
    nodeVmSize: aksNodeVmSize
  }
}

// ── App Service ─────────────────────────────────────────────
module appService 'modules/app-service/main.bicep' = {
  scope: rg
  name: 'appservice-deployment'
  params: {
    name: 'app-${projectName}-${environmentName}'
    location: location
    tags: tags
    skuName: appServiceSkuName
    subnetId: vnet.outputs.subnetIds[1]
  }
}

// ── Outputs ─────────────────────────────────────────────────
output resourceGroupName string = rg.name
output vnetId string = vnet.outputs.vnetId
output aksClusterName string = aks.outputs.clusterName
output appServiceDefaultHostname string = appService.outputs.defaultHostname
output keyVaultUri string = keyVault.outputs.vaultUri
output storageAccountName string = storage.outputs.storageAccountName
