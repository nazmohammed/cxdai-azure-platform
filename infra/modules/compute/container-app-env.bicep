// ============================================================================
// Container Apps Environment — VNet-integrated, internal only
// ============================================================================

@description('Environment name')
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

@description('Container Apps subnet ID (delegated to Microsoft.App/environments)')
param subnetId string

@description('Log Analytics workspace resource ID')
param logAnalyticsWorkspaceId string

// ── Container Apps Environment ──────────────────────────────────────────────

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    workloadProfiles: [
      {
        name: 'Consumption'
        workloadProfileType: 'Consumption'
      }
    ]
    vnetConfiguration: {
      infrastructureSubnetId: subnetId
      internal: true
    }
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: reference(logAnalyticsWorkspaceId, '2023-09-01').customerId
        #disable-next-line use-resource-symbol-reference
        sharedKey: listKeys(logAnalyticsWorkspaceId, '2023-09-01').primarySharedKey
      }
    }
    zoneRedundant: false
    peerTrafficConfiguration: {
      encryption: {
        enabled: false
      }
    }
  }
}

// ── Outputs ─────────────────────────────────────────────────────────────────

output environmentId string = environment.id
output environmentName string = environment.name
output defaultDomain string = environment.properties.defaultDomain
output staticIp string = environment.properties.staticIp
