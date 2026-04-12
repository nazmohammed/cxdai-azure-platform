using '../main.bicep'

param environment = 'staging'
param location = 'swedencentral'
param regionCode = 'sc'
param projectPrefix = 'cxdai'
param fabricSkuName = 'F4'
param fabricAdminMembers = []
param aiSearchSku = 'standard'
param containerAppImage = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
param containerAppCpu = '1.0'
param containerAppMemory = '2Gi'
param tenantId = 'f129bc3c-3fb2-4d3b-85c8-839e1a9bd9e2'
