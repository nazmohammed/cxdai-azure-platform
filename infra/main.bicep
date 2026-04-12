// ============================================================================
// Main Bicep Orchestrator — Subscription-level deployment
// Deploys all resources for the CxDAI secure platform
// ============================================================================
targetScope = 'subscription'

// ── Parameters ──────────────────────────────────────────────────────────────

@description('Environment name (dev, staging, prod)')
@allowed(['dev', 'staging', 'prod'])
param environment string

@description('Azure region for all resources')
param location string = 'swedencentral'

@description('Short region code for naming')
param regionCode string = 'sc'

@description('Project prefix used in resource naming')
param projectPrefix string = 'cxdai'

@description('Tags applied to all resources')
param tags object = {
  project: 'CxDAI'
  environment: environment
  managedBy: 'bicep'
}

@description('Hub VNet address space')
param hubVnetAddressPrefix string = '10.0.0.0/24'

@description('Spoke VNet address space')
param spokeVnetAddressPrefix string = '10.1.0.0/21'

@description('Fabric capacity SKU (F2, F4, F8, etc.)')
@allowed(['F2', 'F4', 'F8', 'F16', 'F32', 'F64'])
param fabricSkuName string = 'F4'

@description('Fabric capacity admin UPNs (email addresses)')
param fabricAdminMembers array = []

@description('AI Search SKU')
@allowed(['basic', 'standard', 'standard2'])
param aiSearchSku string = 'basic'

@description('Container App image (placeholder for initial deploy)')
param containerAppImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Container App CPU cores')
param containerAppCpu string = '0.5'

@description('Container App memory')
param containerAppMemory string = '1Gi'

@description('Deploy VNet Data Gateway (Power Platform enterprise policy — limited region support)')
param deployVnetDataGateway bool = false

@description('VPN client address pool for P2S VPN')
param vpnClientAddressPool string = '172.16.0.0/24'

@description('Entra ID tenant ID (for VPN auth)')
param tenantId string

// ── Resource Groups ─────────────────────────────────────────────────────────

resource hubRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${projectPrefix}-hub-${environment}-${regionCode}'
  location: location
  tags: tags
}

resource spokeRg 'Microsoft.Resources/resourceGroups@2024-03-01' = {
  name: 'rg-${projectPrefix}-spoke-${environment}-${regionCode}'
  location: location
  tags: tags
}

// ── Phase 1: Identity & Monitoring ──────────────────────────────────────────

module managedIdentity 'modules/identity/managed-identity.bicep' = {
  name: 'deploy-managed-identity'
  scope: spokeRg
  params: {
    name: 'uami-${projectPrefix}-${environment}-${regionCode}'
    location: location
    tags: tags
  }
}

module monitoring 'modules/monitoring/monitoring.bicep' = {
  name: 'deploy-monitoring'
  scope: spokeRg
  params: {
    logAnalyticsName: 'law-${projectPrefix}-${environment}-${regionCode}'
    appInsightsName: 'appi-${projectPrefix}-${environment}-${regionCode}'
    location: location
    tags: tags
  }
}

// ── Phase 2: Networking ─────────────────────────────────────────────────────

module hubVnet 'modules/network/hub-vnet.bicep' = {
  name: 'deploy-hub-vnet'
  scope: hubRg
  params: {
    vnetName: 'vnet-hub-${projectPrefix}-${environment}-${regionCode}'
    addressPrefix: hubVnetAddressPrefix
    location: location
    tags: tags
  }
}

module spokeVnet 'modules/network/spoke-vnet.bicep' = {
  name: 'deploy-spoke-vnet'
  scope: spokeRg
  params: {
    vnetName: 'vnet-spoke-${projectPrefix}-${environment}-${regionCode}'
    addressPrefix: spokeVnetAddressPrefix
    location: location
    tags: tags
  }
}

module vnetPeering 'modules/network/vnet-peering.bicep' = {
  name: 'deploy-vnet-peering'
  scope: hubRg
  params: {
    hubVnetName: hubVnet.outputs.vnetName
    hubVnetId: hubVnet.outputs.vnetId
    spokeVnetName: spokeVnet.outputs.vnetName
    spokeVnetId: spokeVnet.outputs.vnetId
    spokeRgName: spokeRg.name
  }
}

module privateDnsZones 'modules/network/private-dns-zones.bicep' = {
  name: 'deploy-private-dns-zones'
  scope: hubRg
  params: {
    hubVnetId: hubVnet.outputs.vnetId
    spokeVnetId: spokeVnet.outputs.vnetId
    tags: tags
  }
}

module vpnGateway 'modules/network/vpn-gateway.bicep' = {
  name: 'deploy-vpn-gateway'
  scope: hubRg
  params: {
    name: 'vpngw-${projectPrefix}-${environment}-${regionCode}'
    location: location
    tags: tags
    gatewaySubnetId: hubVnet.outputs.gatewaySubnetId
    vpnClientAddressPoolPrefix: vpnClientAddressPool
    tenantId: tenantId
  }
}

// ── Phase 3: Security & Storage ─────────────────────────────────────────────

module keyVault 'modules/security/key-vault.bicep' = {
  name: 'deploy-key-vault'
  scope: spokeRg
  params: {
    name: 'kv-${projectPrefix}-${environment}-${regionCode}'
    location: location
    tags: tags
    privateEndpointSubnetId: spokeVnet.outputs.privateEndpointsSubnetId
    privateDnsZoneId: privateDnsZones.outputs.keyVaultDnsZoneId
  }
}

module storageAccount 'modules/storage/storage-account.bicep' = {
  name: 'deploy-storage-account'
  scope: spokeRg
  params: {
    name: 'st${projectPrefix}${environment}${regionCode}'
    location: location
    tags: tags
    privateEndpointSubnetId: spokeVnet.outputs.privateEndpointsSubnetId
    blobDnsZoneId: privateDnsZones.outputs.blobDnsZoneId
    fileDnsZoneId: privateDnsZones.outputs.fileDnsZoneId
  }
}

// ── Phase 4: AI Services ────────────────────────────────────────────────────

module aiFoundryHub 'modules/ai/ai-foundry-hub.bicep' = {
  name: 'deploy-ai-foundry-hub'
  scope: spokeRg
  params: {
    name: 'aih-${projectPrefix}-${environment}-${regionCode}'
    location: location
    tags: tags
    storageAccountId: storageAccount.outputs.storageAccountId
    keyVaultId: keyVault.outputs.keyVaultId
    appInsightsId: monitoring.outputs.appInsightsId
    containerRegistryId: containerRegistry.outputs.registryId
    privateEndpointSubnetId: spokeVnet.outputs.privateEndpointsSubnetId
    amlWorkspaceDnsZoneId: privateDnsZones.outputs.amlWorkspaceDnsZoneId
    notebooksDnsZoneId: privateDnsZones.outputs.notebooksDnsZoneId
  }
}

module aiFoundryProject 'modules/ai/ai-foundry-project.bicep' = {
  name: 'deploy-ai-foundry-project'
  scope: spokeRg
  params: {
    name: 'aip-${projectPrefix}-${environment}-${regionCode}'
    location: location
    tags: tags
    hubId: aiFoundryHub.outputs.hubId
  }
}

module aiSearch 'modules/ai/ai-search.bicep' = {
  name: 'deploy-ai-search'
  scope: spokeRg
  params: {
    name: 'srch-${projectPrefix}-${environment}-${regionCode}'
    location: location
    tags: tags
    sku: aiSearchSku
    privateEndpointSubnetId: spokeVnet.outputs.privateEndpointsSubnetId
    privateDnsZoneId: privateDnsZones.outputs.searchDnsZoneId
  }
}

// ── Phase 5: Compute ────────────────────────────────────────────────────────

module containerRegistry 'modules/compute/container-registry.bicep' = {
  name: 'deploy-container-registry'
  scope: spokeRg
  params: {
    name: 'acr${projectPrefix}${environment}${regionCode}'
    location: location
    tags: tags
    privateEndpointSubnetId: spokeVnet.outputs.privateEndpointsSubnetId
    privateDnsZoneId: privateDnsZones.outputs.acrDnsZoneId
  }
}

module containerAppEnv 'modules/compute/container-app-env.bicep' = {
  name: 'deploy-container-app-env'
  scope: spokeRg
  params: {
    name: 'cae-${projectPrefix}-${environment}-${regionCode}'
    location: location
    tags: tags
    subnetId: spokeVnet.outputs.containerAppsSubnetId
    logAnalyticsWorkspaceId: monitoring.outputs.logAnalyticsWorkspaceId
  }
}

module containerApp 'modules/compute/container-app.bicep' = {
  name: 'deploy-container-app'
  scope: spokeRg
  params: {
    name: 'ca-${projectPrefix}-${environment}-${regionCode}'
    location: location
    tags: tags
    environmentId: containerAppEnv.outputs.environmentId
    userAssignedIdentityId: managedIdentity.outputs.identityId
    registryLoginServer: containerRegistry.outputs.loginServer
    image: containerAppImage
    cpu: containerAppCpu
    memory: containerAppMemory
    aiFoundryEndpoint: aiFoundryHub.outputs.endpoint
    aiSearchEndpoint: aiSearch.outputs.endpoint
    keyVaultUri: keyVault.outputs.vaultUri
    appInsightsConnectionString: monitoring.outputs.appInsightsConnectionString
  }
}

module staticWebApp 'modules/compute/static-web-app.bicep' = {
  name: 'deploy-static-web-app'
  scope: spokeRg
  params: {
    name: 'swa-${projectPrefix}-${environment}-${regionCode}'
    location: 'westeurope' // SWA has limited region support; content is CDN-global
    privateEndpointLocation: location // PE must be in same region as VNet
    tags: tags
    containerAppId: containerApp.outputs.containerAppId
    privateEndpointSubnetId: spokeVnet.outputs.privateEndpointsSubnetId
    privateDnsZoneId: privateDnsZones.outputs.staticWebAppDnsZoneId
  }
}

// ── Phase 6: Fabric ─────────────────────────────────────────────────────────

module fabricCapacity 'modules/fabric/fabric-capacity.bicep' = {
  name: 'deploy-fabric-capacity'
  scope: spokeRg
  params: {
    name: 'fc${projectPrefix}${environment}${regionCode}'
    location: location
    tags: tags
    skuName: fabricSkuName
    adminMembers: fabricAdminMembers
  }
}

module vnetDataGateway 'modules/fabric/vnet-data-gateway.bicep' = if (deployVnetDataGateway) {
  name: 'deploy-vnet-data-gateway'
  scope: spokeRg
  params: {
    name: 'vnetgw-${projectPrefix}-${environment}-${regionCode}'
    location: 'sweden'
    tags: tags
    subnetId: spokeVnet.outputs.fabricGatewaySubnetId
  }
}

// ── Phase 7: RBAC ───────────────────────────────────────────────────────────

module rbacAssignments 'modules/identity/rbac-assignments.bicep' = {
  name: 'deploy-rbac-assignments'
  scope: spokeRg
  params: {
    managedIdentityPrincipalId: managedIdentity.outputs.principalId
    containerRegistryId: containerRegistry.outputs.registryId
    storageAccountId: storageAccount.outputs.storageAccountId
    keyVaultId: keyVault.outputs.keyVaultId
    aiFoundryHubId: aiFoundryHub.outputs.hubId
    aiSearchId: aiSearch.outputs.searchId
  }
}

// ── Outputs ─────────────────────────────────────────────────────────────────

output hubResourceGroupName string = hubRg.name
output spokeResourceGroupName string = spokeRg.name
output managedIdentityId string = managedIdentity.outputs.identityId
output managedIdentityClientId string = managedIdentity.outputs.clientId
output containerAppFqdn string = containerApp.outputs.fqdn
output staticWebAppUrl string = staticWebApp.outputs.defaultHostname
output aiFoundryEndpoint string = aiFoundryHub.outputs.endpoint
output aiSearchEndpoint string = aiSearch.outputs.endpoint
output acrLoginServer string = containerRegistry.outputs.loginServer
output keyVaultUri string = keyVault.outputs.vaultUri
output vpnGatewayPublicIp string = vpnGateway.outputs.publicIpAddress
