# Key Vault Module

Deploys Azure Key Vault with RBAC authorization, soft-delete, purge protection, and optional private endpoint.

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `location` | string | Yes | Azure region |
| `keyVaultName` | string | Yes | Key Vault name (globally unique) |
| `adminObjectId` | string | Yes | Principal ID for Key Vault Administrator role |
| `tags` | object | Yes | Resource tags |
| `enablePurgeProtection` | bool | No | Enable purge protection (default: true) |
| `softDeleteRetentionDays` | int | No | Soft-delete retention (default: 90) |
| `enablePrivateEndpoint` | bool | No | Enable private endpoint (default: true) |
| `privateEndpointSubnetId` | string | No | Subnet for private endpoint |
| `privateDnsZoneId` | string | No | Private DNS Zone for vault resolution |

## Usage

```bicep
module kv 'modules/key-vault/main.bicep' = {
  name: 'kv-deploy'
  params: {
    location: 'eastus2'
    keyVaultName: 'kv-myapp-prod'
    adminObjectId: '00000000-0000-0000-0000-000000000000'
    enablePrivateEndpoint: true
    privateEndpointSubnetId: vnet.outputs.subnetIds[2]
    tags: { environment: 'prod' }
  }
}
```
