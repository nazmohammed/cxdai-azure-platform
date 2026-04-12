// ============================================================================
// AI Search — with Private Endpoint
// ============================================================================

@description('Search service name')
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

@description('Search SKU')
@allowed(['basic', 'standard', 'standard2'])
param sku string = 'basic'

@description('Subnet ID for private endpoint')
param privateEndpointSubnetId string

@description('Private DNS zone ID for search')
param privateDnsZoneId string

// ── AI Search ───────────────────────────────────────────────────────────────

resource search 'Microsoft.Search/searchServices@2024-06-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: { name: sku }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    replicaCount: 1
    partitionCount: 1
    hostingMode: 'default'
    publicNetworkAccess: 'disabled'
    authOptions: {
      aadOrApiKey: {
        aadAuthFailureMode: 'http401WithBearerChallenge'
      }
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
          privateLinkServiceId: search.id
          groupIds: ['searchService']
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
        name: 'privatelink-search-windows-net'
        properties: { privateDnsZoneId: privateDnsZoneId }
      }
    ]
  }
}

// ── Outputs ─────────────────────────────────────────────────────────────────

output searchId string = search.id
output searchName string = search.name
output endpoint string = 'https://${search.name}.search.windows.net'
