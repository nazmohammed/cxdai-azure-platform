// ============================================================================
// Microsoft Fabric Capacity — F SKU
// ============================================================================

@description('Fabric capacity name')
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

@description('Fabric SKU')
@allowed(['F2', 'F4', 'F8', 'F16', 'F32', 'F64'])
param skuName string = 'F4'

@description('Admin member UPNs (email addresses) for Fabric capacity')
param adminMembers array = []

// ── Fabric Capacity ─────────────────────────────────────────────────────────

resource fabricCapacity 'Microsoft.Fabric/capacities@2023-11-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: 'Fabric'
  }
  properties: {
    administration: {
      members: adminMembers
    }
  }
}

// ── Outputs ─────────────────────────────────────────────────────────────────

output capacityId string = fabricCapacity.id
output capacityName string = fabricCapacity.name
