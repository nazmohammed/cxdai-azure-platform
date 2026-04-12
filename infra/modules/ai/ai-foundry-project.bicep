// ============================================================================
// AI Foundry Project — Inherits Hub networking
// ============================================================================

@description('Project name')
param name string

@description('Azure region')
param location string

@description('Resource tags')
param tags object

@description('AI Foundry Hub resource ID')
param hubId string

// ── AI Foundry Project ──────────────────────────────────────────────────────

resource project 'Microsoft.MachineLearningServices/workspaces@2024-10-01' = {
  name: name
  location: location
  tags: tags
  kind: 'Project'
  identity: {
    type: 'SystemAssigned'
  }
  sku: {
    name: 'Basic'
    tier: 'Basic'
  }
  properties: {
    friendlyName: '${name} AI Foundry Project'
    description: 'CxDAI AI Foundry Project'
    hubResourceId: hubId
  }
}

// ── Outputs ─────────────────────────────────────────────────────────────────

output projectId string = project.id
output projectName string = project.name
output principalId string = project.identity.principalId
