# AKS Module

Deploys a production-ready Azure Kubernetes Service cluster with Azure CNI, managed identity, RBAC, Workload Identity, Defender, and Key Vault CSI driver.

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `location` | string | Yes | Azure region |
| `clusterName` | string | Yes | AKS cluster name |
| `kubernetesVersion` | string | Yes | Kubernetes version |
| `systemNodeCount` | int | No | System node pool node count (default: 3) |
| `systemNodeVmSize` | string | No | System node pool VM size |
| `subnetId` | string | Yes | Subnet for AKS nodes |
| `logAnalyticsWorkspaceId` | string | No | Log Analytics workspace for monitoring |
| `tags` | object | Yes | Resource tags |

## Usage

```bicep
module aks 'modules/aks/main.bicep' = {
  name: 'aks-deploy'
  params: {
    location: 'eastus2'
    clusterName: 'aks-app-prod'
    kubernetesVersion: '1.29'
    subnetId: vnet.outputs.subnetIds[1]
    tags: { environment: 'prod' }
  }
}
```
