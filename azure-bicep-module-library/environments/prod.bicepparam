using '../main.bicep'

param environment = 'prod'
param location = 'eastus2'
param vnetAddressPrefix = '10.0.0.0/16'
param aksNodeCount = 3
param aksVmSize = 'Standard_D4s_v5'
param appServiceSkuName = 'S1'
param storageSkuName = 'Standard_ZRS'
param tags = {
  environment: 'prod'
  owner: 'platform-team'
  'cost-center': 'engineering'
  project: 'bicep-modules'
}
