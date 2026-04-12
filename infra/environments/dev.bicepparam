using '../main.bicep'

param environment = 'dev'
param location = 'swedencentral'
param regionCode = 'sc'
param projectPrefix = 'cxdai'
param fabricSkuName = 'F4'
param fabricAdminMembers = ['admin@MngEnvMCAP595042.onmicrosoft.com']
param aiSearchSku = 'basic'
param containerAppImage = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
param containerAppCpu = '0.5'
param containerAppMemory = '1Gi'
param tenantId = 'f129bc3c-3fb2-4d3b-85c8-839e1a9bd9e2'
