// ============================================================================
// Hub VNet — Shared services (DNS, future firewall)
// Address space: 10.0.0.0/24 (256 addresses)
// ============================================================================

@description('VNet name')
param vnetName string

@description('VNet address prefix')
param addressPrefix string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

// ── NSGs ────────────────────────────────────────────────────────────────────

resource nsgDnsResolver 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: 'nsg-${vnetName}-dns-resolver'
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'AllowDnsInbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: '*'
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '53'
        }
      }
      {
        name: 'DenyAllInbound'
        properties: {
          priority: 4096
          direction: 'Inbound'
          access: 'Deny'
          protocol: '*'
          sourceAddressPrefix: '*'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '*'
        }
      }
    ]
  }
}

// ── VNet ────────────────────────────────────────────────────────────────────

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [addressPrefix]
    }
    subnets: [
      {
        name: 'dns-resolver-inbound-snet'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 26, 0) // 10.0.0.0/26
          networkSecurityGroup: { id: nsgDnsResolver.id }
          delegations: [
            {
              name: 'Microsoft.Network.dnsResolvers'
              properties: {
                serviceName: 'Microsoft.Network/dnsResolvers'
              }
            }
          ]
        }
      }
      {
        name: 'dns-resolver-outbound-snet'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 26, 1) // 10.0.0.64/26
          delegations: [
            {
              name: 'Microsoft.Network.dnsResolvers'
              properties: {
                serviceName: 'Microsoft.Network/dnsResolvers'
              }
            }
          ]
        }
      }
      {
        name: 'AzureFirewallSubnet'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 26, 2) // 10.0.0.128/26
        }
      }
      {
        name: 'GatewaySubnet'
        properties: {
          addressPrefix: cidrSubnet(addressPrefix, 26, 3) // 10.0.0.192/26
        }
      }
    ]
  }
}

// ── Outputs ─────────────────────────────────────────────────────────────────

output vnetId string = vnet.id
output vnetName string = vnet.name
output dnsResolverInboundSubnetId string = vnet.properties.subnets[0].id
output dnsResolverOutboundSubnetId string = vnet.properties.subnets[1].id
output gatewaySubnetId string = vnet.properties.subnets[3].id
