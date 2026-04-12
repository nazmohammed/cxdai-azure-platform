// ============================================================================
// Static Web App — Standard SKU + Linked Backend (→ Container App) + PE
// ============================================================================

@description('Static Web App name')
param name string

@description('Azure region for SWA resource (limited availability)')
param location string

@description('Azure region for Private Endpoint (must match VNet region)')
param privateEndpointLocation string

@description('Resource tags')
param tags object

@description('Container App resource ID for linked backend')
param containerAppId string

@description('Subnet ID for private endpoint')
param privateEndpointSubnetId string

@description('Private DNS zone ID for Static Web App')
param privateDnsZoneId string

// ── Static Web App ──────────────────────────────────────────────────────────

resource staticWebApp 'Microsoft.Web/staticSites@2024-04-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Standard'
  }
  properties: {
    stagingEnvironmentPolicy: 'Enabled'
    allowConfigFileUpdates: true
    enterpriseGradeCdnStatus: 'Disabled'
  }
}

// ── Linked Backend (routes /api/* to Container App) ─────────────────────────

resource linkedBackend 'Microsoft.Web/staticSites/linkedBackends@2024-04-01' = {
  parent: staticWebApp
  name: 'container-app-backend'
  properties: {
    backendResourceId: containerAppId
    region: privateEndpointLocation
  }
}

// ── Private Endpoint ────────────────────────────────────────────────────────

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2024-05-01' = {
  name: 'pe-${name}'
  location: privateEndpointLocation
  tags: tags
  properties: {
    subnet: { id: privateEndpointSubnetId }
    privateLinkServiceConnections: [
      {
        name: 'pe-${name}-connection'
        properties: {
          privateLinkServiceId: staticWebApp.id
          groupIds: ['staticSites']
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
        name: 'privatelink-azurestaticapps-net'
        properties: { privateDnsZoneId: privateDnsZoneId }
      }
    ]
  }
}

// ── Outputs ─────────────────────────────────────────────────────────────────

output staticWebAppId string = staticWebApp.id
output staticWebAppName string = staticWebApp.name
output defaultHostname string = staticWebApp.properties.defaultHostname
