using '../main.bicep'

param environment = 'dev'
param location = 'eastus2'
param vnetAddressPrefix = '10.100.0.0/16'
param aksNodeCount = 2
param aksVmSize = 'Standard_D2s_v5'
param appServiceSkuName = 'B1'
param storageSkuName = 'Standard_LRS'
param tags = {
  environment: 'dev'
  owner: 'platform-team'
  'cost-center': 'engineering'
  project: 'bicep-modules'
}
