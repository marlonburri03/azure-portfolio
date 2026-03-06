# App Service Module

Deploys an Azure App Service with VNet integration, system-assigned managed identity, staging slot, and HTTPS-only enforcement.

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `location` | string | Yes | Azure region |
| `appName` | string | Yes | App Service name |
| `appServicePlanSkuName` | string | No | SKU (default: S1) |
| `runtimeStack` | string | No | Runtime (default: DOTNET\|8.0) |
| `subnetId` | string | No | Subnet for VNet integration |
| `tags` | object | Yes | Resource tags |
| `enableStagingSlot` | bool | No | Create a staging slot (default: true) |

## Usage

```bicep
module app 'modules/app-service/main.bicep' = {
  name: 'app-deploy'
  params: {
    location: 'eastus2'
    appName: 'app-api-prod'
    subnetId: vnet.outputs.subnetIds[0]
    tags: { environment: 'prod' }
  }
}
```
