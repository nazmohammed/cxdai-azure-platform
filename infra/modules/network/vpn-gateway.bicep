// ============================================================================
// VPN Gateway — P2S with Entra ID (Azure AD) authentication
// ============================================================================

@description('Gateway name')
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

@description('Gateway subnet ID (must be named GatewaySubnet)')
param gatewaySubnetId string

@description('VPN client address pool (e.g., 172.16.0.0/24)')
param vpnClientAddressPoolPrefix string = '172.16.0.0/24'

@description('Entra ID tenant ID for VPN authentication')
param tenantId string

@description('VPN Gateway SKU')
@allowed(['VpnGw1AZ', 'VpnGw2AZ', 'VpnGw3AZ'])
param skuName string = 'VpnGw1AZ'

// Azure VPN Enterprise Application ID (Azure Public Cloud)
var azureVpnAppId = '41b23e61-6c1e-4545-b367-cd054e0ed4b4'
var aadIssuer = 'https://sts.windows.net/${tenantId}/'
#disable-next-line no-hardcoded-env-urls
var aadTenant = 'https://login.microsoftonline.com/${tenantId}/'
var aadAudience = azureVpnAppId

// ── Public IP ───────────────────────────────────────────────────────────────

resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: 'pip-${name}'
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  zones: ['1', '2', '3']
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

// ── VPN Gateway ─────────────────────────────────────────────────────────────

resource vpnGateway 'Microsoft.Network/virtualNetworkGateways@2024-05-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    gatewayType: 'Vpn'
    vpnType: 'RouteBased'
    sku: {
      name: skuName
      tier: skuName
    }
    ipConfigurations: [
      {
        name: 'default'
        properties: {
          publicIPAddress: { id: publicIp.id }
          subnet: { id: gatewaySubnetId }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    vpnClientConfiguration: {
      vpnClientAddressPool: {
        addressPrefixes: [vpnClientAddressPoolPrefix]
      }
      vpnClientProtocols: ['OpenVPN']
      vpnAuthenticationTypes: ['AAD']
      aadTenant: aadTenant
      aadAudience: aadAudience
      aadIssuer: aadIssuer
    }
    vpnGatewayGeneration: 'Generation1'
    enableBgp: false
    activeActive: false
  }
}

// ── Outputs ─────────────────────────────────────────────────────────────────

output gatewayId string = vpnGateway.id
output gatewayName string = vpnGateway.name
output publicIpAddress string = publicIp.properties.ipAddress
output vpnClientAddressPool string = vpnClientAddressPoolPrefix
