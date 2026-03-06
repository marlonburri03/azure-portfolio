// ──────────────────────────────────────────────────────────
// Module: Production-ready AKS cluster with managed identity
// ──────────────────────────────────────────────────────────

@description('Name of the AKS cluster.')
param name string

@description('Azure region for deployment.')
param location string

@description('Resource tags.')
param tags object

@description('Subnet ID for the default node pool (Azure CNI).')
param subnetId string

@description('Node count for the system node pool.')
@minValue(1)
@maxValue(50)
param nodeCount int = 3

@description('VM size for the system node pool.')
param nodeVmSize string = 'Standard_D4s_v5'

@description('Kubernetes version. Empty string uses the latest stable version.')
param kubernetesVersion string = ''

@description('Enable Azure Monitor (Container Insights) for observability.')
param enableMonitoring bool = true

@description('Log Analytics workspace ID for Container Insights.')
param logAnalyticsWorkspaceId string = ''

@description('Enable Microsoft Defender for Containers.')
param enableDefender bool = true

@description('Disk size in GB for each node.')
param osDiskSizeGB int = 128

// Managed identity is preferred over service principal for security
resource aks 'Microsoft.ContainerService/managedClusters@2024-02-01' = {
  name: name
  location: location
  tags: tags
  identity: {
    // System-assigned identity eliminates credential management
    type: 'SystemAssigned'
  }
  properties: {
    // Leave empty for latest stable version
    kubernetesVersion: !empty(kubernetesVersion) ? kubernetesVersion : null
    dnsPrefix: name
    enableRBAC: true
    aadProfile: {
      // Azure AD integration for cluster access control
      managed: true
      enableAzureRBAC: true
    }
    networkProfile: {
      // Azure CNI for direct pod-VNet integration
      networkPlugin: 'azure'
      networkPolicy: 'azure'
      serviceCidr: '172.16.0.0/16'
      dnsServiceIP: '172.16.0.10'
      loadBalancerSku: 'standard'
    }
    agentPoolProfiles: [
      {
        name: 'system'
        count: nodeCount
        vmSize: nodeVmSize
        osType: 'Linux'
        mode: 'System'
        vnetSubnetID: subnetId
        osDiskSizeGB: osDiskSizeGB
        // Availability zones for high availability
        availabilityZones: ['1', '2', '3']
        // Auto-scaling for cost optimization
        enableAutoScaling: true
        minCount: nodeCount
        maxCount: nodeCount * 2
        // Ephemeral OS disks for better performance and lower cost
        osDiskType: 'Ephemeral'
        type: 'VirtualMachineScaleSets'
        nodeTaints: [
          // System taint ensures only system pods run here
          'CriticalAddonsOnly=true:NoSchedule'
        ]
      }
    ]
    // Auto-upgrade to patch versions for security
    autoUpgradeProfile: {
      upgradeChannel: 'patch'
    }
    // OMS agent for Container Insights
    addonProfiles: {
      omsagent: {
        enabled: enableMonitoring
        config: enableMonitoring && !empty(logAnalyticsWorkspaceId)
          ? { logAnalyticsWorkspaceResourceID: logAnalyticsWorkspaceId }
          : null
      }
      azureKeyvaultSecretsProvider: {
        // Secrets Store CSI driver for native Key Vault integration
        enabled: true
        config: {
          enableSecretRotation: 'true'
        }
      }
    }
    securityProfile: {
      defender: {
        securityMonitoring: {
          enabled: enableDefender
        }
      }
    }
  }
}

@description('The name of the AKS cluster.')
output clusterName string = aks.name

@description('The resource ID of the AKS cluster.')
output clusterId string = aks.id

@description('The FQDN of the AKS API server.')
output clusterFqdn string = aks.properties.fqdn

@description('The principal ID of the cluster managed identity.')
output identityPrincipalId string = aks.identity.principalId
