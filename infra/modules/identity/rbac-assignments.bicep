// ============================================================================
// RBAC Role Assignments — All roles for UAMI across resources
// ============================================================================

@description('Managed Identity principal ID')
param managedIdentityPrincipalId string

@description('Container Registry resource ID')
param containerRegistryId string

@description('Storage Account resource ID')
param storageAccountId string

@description('Key Vault resource ID')
param keyVaultId string

@description('AI Foundry Hub resource ID')
param aiFoundryHubId string

@description('AI Search resource ID')
param aiSearchId string

// ── Role Definition IDs (built-in) ─────────────────────────────────────────

var roles = {
  acrPull: '7f951dda-4ed3-4680-a7ca-43fe172d538d'
  storageBlobDataContributor: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  keyVaultSecretsUser: '4633458b-17de-408a-b874-0445c86b69e6'
  cognitiveServicesOpenAIUser: '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
  searchIndexDataReader: '1407120a-92aa-4202-b7e9-c0e197c71c8f'
  searchServiceContributor: '7ca78c08-252a-4471-8644-bb5ff32d4ba0'
  cognitiveServicesUser: 'a97b65f3-24c7-4388-baec-2e87135dc908'
}

// ── ACR Pull ────────────────────────────────────────────────────────────────

resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistryId, managedIdentityPrincipalId, roles.acrPull)
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.acrPull)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: last(split(containerRegistryId, '/'))
}

// ── Storage Blob Data Contributor ───────────────────────────────────────────

resource storageBlobAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(storageAccountId, managedIdentityPrincipalId, roles.storageBlobDataContributor)
  scope: storageAccount
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.storageBlobDataContributor)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: last(split(storageAccountId, '/'))
}

// ── Key Vault Secrets User ──────────────────────────────────────────────────

resource kvSecretsAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(keyVaultId, managedIdentityPrincipalId, roles.keyVaultSecretsUser)
  scope: keyVault
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.keyVaultSecretsUser)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' existing = {
  name: last(split(keyVaultId, '/'))
}

// ── Cognitive Services OpenAI User (AI Foundry) ─────────────────────────────

resource openAIUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiFoundryHubId, managedIdentityPrincipalId, roles.cognitiveServicesOpenAIUser)
  scope: aiFoundryHub
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.cognitiveServicesOpenAIUser)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource aiFoundryHub 'Microsoft.MachineLearningServices/workspaces@2024-10-01' existing = {
  name: last(split(aiFoundryHubId, '/'))
}

// ── Cognitive Services User (AI Foundry — agent write, etc.) ────────────────

resource cogServicesUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiFoundryHubId, managedIdentityPrincipalId, roles.cognitiveServicesUser)
  scope: aiFoundryHub
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.cognitiveServicesUser)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

// ── Search Index Data Reader ────────────────────────────────────────────────

resource searchReaderAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiSearchId, managedIdentityPrincipalId, roles.searchIndexDataReader)
  scope: aiSearch
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.searchIndexDataReader)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}

resource aiSearch 'Microsoft.Search/searchServices@2024-06-01-preview' existing = {
  name: last(split(aiSearchId, '/'))
}

// ── Search Service Contributor ──────────────────────────────────────────────

resource searchContributorAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(aiSearchId, managedIdentityPrincipalId, roles.searchServiceContributor)
  scope: aiSearch
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roles.searchServiceContributor)
    principalId: managedIdentityPrincipalId
    principalType: 'ServicePrincipal'
  }
}
