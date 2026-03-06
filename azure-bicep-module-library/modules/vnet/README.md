# VNet Module

Deploys an Azure Virtual Network with configurable subnets, NSG association, custom DNS, and optional DDoS protection.

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `location` | string | Yes | Azure region |
| `vnetName` | string | Yes | VNet name |
| `addressPrefixes` | array | Yes | Address space CIDR blocks |
| `subnets` | array | Yes | Subnet definitions (name, prefix, nsgId, delegations) |
| `tags` | object | Yes | Resource tags |
| `dnsServers` | array | No | Custom DNS servers |
| `enableDdosProtection` | bool | No | Enable DDoS Protection Plan |

## Usage

```bicep
module vnet 'modules/vnet/main.bicep' = {
  name: 'vnet-deploy'
  params: {
    location: 'eastus2'
    vnetName: 'vnet-hub-prod'
    addressPrefixes: ['10.0.0.0/16']
    subnets: [
      { name: 'snet-default', addressPrefix: '10.0.1.0/24' }
      { name: 'snet-aks', addressPrefix: '10.0.2.0/22' }
    ]
    tags: { environment: 'prod' }
  }
}
```
