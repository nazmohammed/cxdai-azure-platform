// ============================================================================
// AI Foundry Hub — Microsoft.MachineLearningServices/workspaces (kind: Hub)
// publicNetworkAccess: Disabled + Private Endpoint
// ============================================================================

@description('Hub name')
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

@description('Storage Account resource ID (dependency)')
param storageAccountId string

@description('Key Vault resource ID (dependency)')
param keyVaultId string

@description('Application Insights resource ID (dependency)')
param appInsightsId string

@description('Container Registry resource ID (dependency)')
param containerRegistryId string

@description('Subnet ID for private endpoint')
param privateEndpointSubnetId string

@description('Private DNS zone ID for amlworkspace')
param amlWorkspaceDnsZoneId string

@description('Private DNS zone ID for notebooks')
param notebooksDnsZoneId string

// ── AI Foundry Hub ──────────────────────────────────────────────────────────

resource hub 'Microsoft.MachineLearningServices/workspaces@2024-10-01' = {
  name: name
  location: location
  tags: tags
  kind: 'Hub'
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    friendlyName: '${name} AI Foundry Hub'
    description: 'CxDAI AI Foundry Hub with private networking'
    storageAccount: storageAccountId
    keyVault: keyVaultId
    applicationInsights: appInsightsId
    containerRegistry: containerRegistryId
    publicNetworkAccess: 'Disabled'
    managedNetwork: {
      isolationMode: 'AllowInternetOutbound'
    }
  }
}

// ── Private Endpoint ────────────────────────────────────────────────────────

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-${name}'
  location: location
  tags: tags
  properties: {
    subnet: { id: privateEndpointSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'pe-${name}-connection'
        properties: {
          privateLinkServiceId: hub.id
          groupIds: ['amlworkspace']
        }
      }
    ]
  }
}

resource dnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2024-05-01' = {
  parent: privateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-api-azureml-ms'
        properties: { privateDnsZoneId: amlWorkspaceDnsZoneId }
      }
      {
        name: 'privatelink-notebooks-azure-net'
        properties: { privateDnsZoneId: notebooksDnsZoneId }
      }
    ]
  }
}

// ── Outputs ─────────────────────────────────────────────────────────────────

output hubId string = hub.id
output hubName string = hub.name
output endpoint string = 'https://${hub.name}.api.azureml.ms'
output principalId string = hub.identity.principalId
