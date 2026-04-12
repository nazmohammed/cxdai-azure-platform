// ============================================================================
// VNet Peering — Bidirectional Hub ↔ Spoke
// ============================================================================

@description('Hub VNet name')
param hubVnetName string

@description('Hub VNet resource ID')
param hubVnetId string

@description('Spoke VNet name')
param spokeVnetName string

@description('Spoke VNet resource ID')
param spokeVnetId string

@description('Spoke resource group name')
param spokeRgName string

// ── Hub → Spoke peering ─────────────────────────────────────────────────────

resource hubToSpoke 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  name: '${hubVnetName}/peer-to-spoke'
  properties: {
    remoteVirtualNetwork: { id: spokeVnetId }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}

// ── Spoke → Hub peering ─────────────────────────────────────────────────────

module spokeToHub 'spoke-to-hub-peering.bicep' = {
  name: 'deploy-spoke-to-hub-peering'
  scope: resourceGroup(spokeRgName)
  params: {
    spokeVnetName: spokeVnetName
    hubVnetId: hubVnetId
  }
}
