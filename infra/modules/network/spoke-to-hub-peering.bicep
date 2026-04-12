// ============================================================================
// Spoke → Hub peering (deployed in spoke RG scope)
// ============================================================================

@description('Spoke VNet name')
param spokeVnetName string

@description('Hub VNet resource ID')
param hubVnetId string

resource spokeToHub 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
  name: '${spokeVnetName}/peer-to-hub'
  properties: {
    remoteVirtualNetwork: { id: hubVnetId }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
    allowGatewayTransit: false
    useRemoteGateways: false
  }
}
