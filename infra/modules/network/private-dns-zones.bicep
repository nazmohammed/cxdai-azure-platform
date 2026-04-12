// ============================================================================
// Private DNS Zones — All privatelink.* zones linked to Hub + Spoke VNets
// ============================================================================

@description('Hub VNet resource ID for DNS zone link')
param hubVnetId string

@description('Spoke VNet resource ID for DNS zone link')
param spokeVnetId string

@description('Resource tags')
param tags object

// ── DNS Zone definitions ────────────────────────────────────────────────────

var dnsZones = [
  // These are Azure Private Link DNS zone names — hardcoded by design
  #disable-next-line no-hardcoded-env-urls
  'privatelink.blob.core.windows.net'
  #disable-next-line no-hardcoded-env-urls
  'privatelink.file.core.windows.net'
]

var dnsZonesNonEnv = [
  'privatelink.api.azureml.ms'
  'privatelink.notebooks.azure.net'
  'privatelink.vaultcore.azure.net'
  'privatelink.search.windows.net'
  'privatelink.azurecr.io'
  'privatelink.azurestaticapps.net'
  'privatelink.analysis.windows.net'
  'privatelink.cognitiveservices.azure.com'
]

var allDnsZones = concat(dnsZonesNonEnv, dnsZones)

// ── Create DNS Zones ────────────────────────────────────────────────────────

resource zones 'Microsoft.Network/privateDnsZones@2024-06-01' = [
  for zone in allDnsZones: {
    name: zone
    location: 'global'
    tags: tags
  }
]

// ── Link to Hub VNet ────────────────────────────────────────────────────────

resource hubLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [
  for (zone, i) in allDnsZones: {
    parent: zones[i]
    name: 'link-hub'
    location: 'global'
    properties: {
      virtualNetwork: { id: hubVnetId }
      registrationEnabled: false
    }
  }
]

// ── Link to Spoke VNet ──────────────────────────────────────────────────────

resource spokeLinks 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2024-06-01' = [
  for (zone, i) in allDnsZones: {
    parent: zones[i]
    name: 'link-spoke'
    location: 'global'
    properties: {
      virtualNetwork: { id: spokeVnetId }
      registrationEnabled: false
    }
  }
]

// ── Outputs ─────────────────────────────────────────────────────────────────

// Outputs — indexed against allDnsZones = concat(dnsZonesNonEnv, dnsZones)
// [0] privatelink.api.azureml.ms        [5] privatelink.search.windows.net
// [1] privatelink.notebooks.azure.net    [6] privatelink.azurecr.io
// [2] privatelink.vaultcore.azure.net    [7] privatelink.azurestaticapps.net
// [3] privatelink.analysis.windows.net   [8] privatelink.blob.core.windows.net
// [4] privatelink.cognitiveservices...   [9] privatelink.file.core.windows.net

output amlWorkspaceDnsZoneId string = zones[0].id
output notebooksDnsZoneId string = zones[1].id
output keyVaultDnsZoneId string = zones[2].id
output searchDnsZoneId string = zones[3].id
output acrDnsZoneId string = zones[4].id
output staticWebAppDnsZoneId string = zones[5].id
output fabricDnsZoneId string = zones[6].id
output cognitiveServicesDnsZoneId string = zones[7].id
output blobDnsZoneId string = zones[8].id
output fileDnsZoneId string = zones[9].id
