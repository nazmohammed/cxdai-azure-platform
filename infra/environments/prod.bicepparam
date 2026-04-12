using '../main.bicep'

param environment = 'prod'
param location = 'swedencentral'
param regionCode = 'sc'
param projectPrefix = 'cxdai'
param fabricSkuName = 'F8'
param fabricAdminMembers = []
param aiSearchSku = 'standard2'
param containerAppImage = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
param containerAppCpu = '2.0'
param containerAppMemory = '4Gi'
param tenantId = 'f129bc3c-3fb2-4d3b-85c8-839e1a9bd9e2'
