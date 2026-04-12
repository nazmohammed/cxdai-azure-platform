// ============================================================================
// Container Registry — Premium SKU (required for Private Endpoint)
// ============================================================================

@description('Registry name (alphanumeric only)')
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

@description('Subnet ID for private endpoint')
param privateEndpointSubnetId string

@description('Private DNS zone ID for ACR')
param privateDnsZoneId string

// ── Container Registry ──────────────────────────────────────────────────────

resource registry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: name
  location: location
  tags: tags
  sku: { name: 'Premium' }
  properties: {
    adminUserEnabled: false
    publicNetworkAccess: 'Disabled'
    networkRuleBypassOptions: 'AzureServices'
    zoneRedundancy: 'Disabled'
    dataEndpointEnabled: false
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
          privateLinkServiceId: registry.id
          groupIds: ['registry']
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
        name: 'privatelink-azurecr-io'
        properties: { privateDnsZoneId: privateDnsZoneId }
      }
    ]
  }
}

// ── Outputs ─────────────────────────────────────────────────────────────────

output registryId string = registry.id
output registryName string = registry.name
output loginServer string = registry.properties.loginServer
