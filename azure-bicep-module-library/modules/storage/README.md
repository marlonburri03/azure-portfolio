# Storage Module

Deploys Azure Storage Account with lifecycle management, blob versioning, soft-delete, and optional private endpoint. Shared key access is disabled by default — forces AAD authentication.

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `location` | string | Yes | Azure region |
| `storageAccountName` | string | Yes | Storage account name (globally unique) |
| `tags` | object | Yes | Resource tags |
| `skuName` | string | No | SKU (default: Standard_ZRS) |
| `enableVersioning` | bool | No | Enable blob versioning (default: true) |
| `blobSoftDeleteDays` | int | No | Blob soft-delete retention (default: 30) |
| `moveToCoolAfterDays` | int | No | Days before tiering to Cool (default: 30) |
| `deleteAfterDays` | int | No | Days before deletion (default: 365) |
| `enablePrivateEndpoint` | bool | No | Enable private endpoint (default: true) |
| `privateEndpointSubnetId` | string | No | Subnet for private endpoint |
| `privateDnsZoneId` | string | No | Private DNS Zone for blob resolution |

## Usage

```bicep
module stg 'modules/storage/main.bicep' = {
  name: 'storage-deploy'
  params: {
    location: 'eastus2'
    storageAccountName: 'stmyappprod'
    enablePrivateEndpoint: true
    privateEndpointSubnetId: vnet.outputs.subnetIds[2]
    tags: { environment: 'prod' }
  }
}
```
