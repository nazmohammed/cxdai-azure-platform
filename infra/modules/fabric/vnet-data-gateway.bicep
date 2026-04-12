// ============================================================================
// VNet Data Gateway — For Fabric private connectivity
// Note: VNet Data Gateway is provisioned via Power Platform / Fabric APIs.
// This module creates the supporting infrastructure (subnet delegation is
// handled in spoke-vnet.bicep). The actual gateway registration happens
// via PowerShell/REST API post-deployment.
// ============================================================================

@description('Gateway name')
param name string

@description('Power Platform geo-level region (e.g., sweden, europe, unitedstates)')
param location string

@description('Resource tags')
param tags object

@description('Fabric gateway subnet ID (delegated to Microsoft.PowerPlatform/vnetaccesslinks)')
param subnetId string

// ── VNet Access Link (Power Platform) ───────────────────────────────────────
// The Microsoft.PowerPlatform/enterprisePolicies resource enables VNet
// integration for Power Platform / Fabric workloads.

resource enterprisePolicy 'Microsoft.PowerPlatform/enterprisePolicies@2020-10-30-preview' = {
  name: name
  location: location
  tags: tags
  kind: 'NetworkInjection'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    networkInjection: {
      virtualNetworks: [
        {
          id: subnetId
        }
      ]
    }
  }
}

// ── Outputs ─────────────────────────────────────────────────────────────────

output policyId string = enterprisePolicy.id
output policyName string = enterprisePolicy.name
output principalId string = enterprisePolicy.identity.systemAssignedIdentityPrincipalId
