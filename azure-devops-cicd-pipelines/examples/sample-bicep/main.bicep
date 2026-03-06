// =============================================================================
// Sample Azure Bicep Deployment — Main Template
// =============================================================================
// Demonstrates the resource patterns used with the Bicep deployment pipeline.
// Deploys a resource group, ACR, and AKS cluster with proper tagging.
// =============================================================================

targetScope = 'subscription'

// ---------------------------------------------------------------------------
// Parameters
// ---------------------------------------------------------------------------
@allowed(['dev', 'staging', 'prod'])
@description('Deployment environment')
param environment string

@description('Azure region for all resources')
param location string = 'eastus2'

@description('Project identifier used in resource naming')
param projectName string = 'portfolio'

@description('Team or individual responsible for these resources')
param owner string

@description('Finance cost center code for chargeback')
param costCenter string

@description('Kubernetes version for AKS')
param kubernetesVersion string = '1.29'

@description('VM size for AKS system node pool')
param aksNodeVmSize string = 'Standard_D4s_v5'

@description('Number of nodes in the system pool')
@minValue(1)
@maxValue(100)
param aksNodeCount int = 3

// ---------------------------------------------------------------------------
// Variables
// ---------------------------------------------------------------------------
// Common tags applied to every resource for governance and cost tracking
var commonTags = {
  Environment: environment
  Owner: owner
  CostCenter: costCenter
  Project: projectName
  ManagedBy: 'bicep'
}

var resourceGroupName = 'rg-${projectName}-${environment}'
// ACR names must be alphanumeric — strip hyphens
var acrName = replace('acr${projectName}${environment}', '-', '')
var aksName = 'aks-${projectName}-${environment}'
var vnetName = 'vnet-${projectName}-${environment}'

// ---------------------------------------------------------------------------
// Resource Group
// ---------------------------------------------------------------------------
resource rg 'Microsoft.Resources/resourceGroups@2023-07-01' = {
  name: resourceGroupName
  location: location
  tags: commonTags
}

// ---------------------------------------------------------------------------
// Module: Networking
// ---------------------------------------------------------------------------
// Deployed into the resource group created above
module networking 'modules/networking.bicep' = {
  scope: rg
  name: 'networking-${uniqueString(rg.id)}'
  params: {
    vnetName: vnetName
    location: location
    tags: commonTags
    vnetAddressPrefix: '10.0.0.0/16'
    aksSubnetPrefix: '10.0.0.0/20'
  }
}

// ---------------------------------------------------------------------------
// Module: Azure Container Registry
// ---------------------------------------------------------------------------
module acr 'modules/acr.bicep' = {
  scope: rg
  name: 'acr-${uniqueString(rg.id)}'
  params: {
    acrName: acrName
    location: location
    tags: commonTags
    // Premium SKU for prod enables geo-replication and private endpoints
    sku: environment == 'prod' ? 'Premium' : 'Standard'
  }
}

// ---------------------------------------------------------------------------
// Module: Azure Kubernetes Service
// ---------------------------------------------------------------------------
module aks 'modules/aks.bicep' = {
  scope: rg
  name: 'aks-${uniqueString(rg.id)}'
  params: {
    aksName: aksName
    location: location
    tags: commonTags
    kubernetesVersion: kubernetesVersion
    nodeVmSize: aksNodeVmSize
    nodeCount: aksNodeCount
    subnetId: networking.outputs.aksSubnetId
  }
}

// ---------------------------------------------------------------------------
// Role Assignment: AKS → ACR Pull (allows cluster to pull container images)
// ---------------------------------------------------------------------------
// AcrPull role definition ID is a well-known GUID
var acrPullRoleId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')

module acrPullRole 'modules/role-assignment.bicep' = {
  scope: rg
  name: 'acr-pull-${uniqueString(rg.id)}'
  params: {
    principalId: aks.outputs.kubeletIdentityObjectId
    roleDefinitionId: acrPullRoleId
    principalType: 'ServicePrincipal'
  }
}

// ---------------------------------------------------------------------------
// Outputs — consumed by downstream pipeline stages
// ---------------------------------------------------------------------------
output resourceGroupName string = rg.name
output acrLoginServer string = acr.outputs.loginServer
output aksClusterName string = aks.outputs.clusterName
