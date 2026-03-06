# NSG Module

Deploys a Network Security Group with a default deny-all inbound rule and common allow rules (HTTPS, SSH) that can be merged with custom rules.

## Parameters

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `location` | string | Yes | Azure region |
| `nsgName` | string | Yes | NSG name |
| `tags` | object | Yes | Resource tags |
| `customRules` | array | No | Additional security rules to merge with defaults |

## Usage

```bicep
module nsg 'modules/nsg/main.bicep' = {
  name: 'nsg-deploy'
  params: {
    location: 'eastus2'
    nsgName: 'nsg-web-prod'
    tags: { environment: 'prod' }
    customRules: [
      {
        name: 'Allow-HTTPS'
        properties: {
          priority: 200
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: '*'
          destinationPortRange: '443'
        }
      }
    ]
  }
}
```
