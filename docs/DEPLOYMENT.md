# Deployment Guide

## Prerequisites

### Tools

| Tool | Version | Install |
|------|---------|---------|
| Azure CLI | 2.50+ | `winget install Microsoft.AzureCLI` |
| Bicep CLI | 0.40+ | `az bicep install` or `az bicep upgrade` |
| Azure VPN Client | Latest | [Download](https://aka.ms/azvpnclientdownload) |

### Azure Permissions

- **Subscription-level**: Owner or Contributor + User Access Administrator
- **Entra ID**: Application Administrator (for VPN enterprise app consent)

### Resource Provider Registration

```bash
az provider register --namespace Microsoft.App
az provider register --namespace Microsoft.Fabric
az provider register --namespace Microsoft.MachineLearningServices
az provider register --namespace Microsoft.Search
az provider register --namespace Microsoft.ContainerRegistry
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.PowerPlatform
```

## Step-by-Step Deployment

### 1. Authenticate

```bash
az login
az account set --subscription "<subscription-id>"
az account show  # Verify correct subscription
```

### 2. Validate (Dry Run)

```bash
cd infra

# Lint check
az bicep lint --file main.bicep

# What-if (shows what will be created/modified/deleted)
az deployment sub what-if \
  --location swedencentral \
  --template-file main.bicep \
  --parameters environments/dev.bicepparam
```

### 3. Deploy

```bash
az deployment sub create \
  --name "cxdai-dev-deploy-$(date +%Y%m%d-%H%M%S)" \
  --location swedencentral \
  --template-file main.bicep \
  --parameters environments/dev.bicepparam
```

Deployment takes approximately **20-30 minutes** (VPN Gateway is the slowest component).

### 4. Verify Deployment

```bash
# Check deployment status
az deployment sub show \
  --name "<deployment-name>" \
  --query "properties.{state:provisioningState, outputs:outputs}" \
  -o json

# List resources in both resource groups
az resource list --resource-group rg-cxdai-hub-dev-sc -o table
az resource list --resource-group rg-cxdai-spoke-dev-sc -o table
```

### 5. Grant Azure VPN Enterprise App Consent

Before connecting via P2S VPN, grant admin consent for the Azure VPN app in your tenant:

1. Navigate to **Azure Portal** → **Entra ID** → **Enterprise Applications**
2. Search for **Azure VPN** (App ID: `41b23e61-6c1e-4545-b367-cd054e0ed4b4`)
3. Click **Grant admin consent**
4. Alternatively, open this URL (replace `{tenant-id}`):
   ```
   https://login.microsoftonline.com/{tenant-id}/adminconsent?client_id=41b23e61-6c1e-4545-b367-cd054e0ed4b4
   ```

### 6. Configure VPN Client

1. In Azure Portal, go to **vpngw-cxdai-dev-sc** → **Point-to-site configuration**
2. Click **Download VPN client**
3. Extract the ZIP file
4. Open **Azure VPN Client** app
5. Import the `azurevpnconfig.xml` from the extracted folder
6. Connect using your Entra ID credentials
7. Verify connectivity:
   ```bash
   nslookup kv-cxdai-dev-sc.vault.azure.net       # Should resolve to 10.1.2.x
   nslookup aih-cxdai-dev-sc.api.azureml.ms        # Should resolve to 10.1.2.x
   nslookup srch-cxdai-dev-sc.search.windows.net    # Should resolve to 10.1.2.x
   ```

## Post-Deployment Setup

### Fabric Configuration

Fabric is SaaS — Bicep creates the capacity, but workspace setup is done via portal:

1. **Enable Fabric Private Link** (tenant admin):
   - Fabric Admin Portal → Tenant Settings → Advanced Networking → Azure Private Links → Enable
2. **Create Workspace**:
   - fabric.microsoft.com → Workspaces → New Workspace → Select `fccxdaidevsc` capacity
3. **VNet Data Gateway** (optional, manual):
   - Fabric Settings → Manage connections and gateways → New → Virtual Network data gateway
   - Select the `fabric-gateway-snet` subnet

### Push Container Image to ACR

```bash
# Connect VPN first, then:
az acr login --name acrcxdaidevsc

docker build -t acrcxdaidevsc.azurecr.io/myapp:v1 .
docker push acrcxdaidevsc.azurecr.io/myapp:v1

# Update Container App
az containerapp update \
  --name ca-cxdai-dev-sc \
  --resource-group rg-cxdai-spoke-dev-sc \
  --image acrcxdaidevsc.azurecr.io/myapp:v1
```

### Deploy Frontend to Static Web App

```bash
# Get SWA deployment token
az staticwebapp secrets list \
  --name swa-cxdai-dev-sc \
  --resource-group rg-cxdai-spoke-dev-sc \
  --query "properties.apiKey" -o tsv

# Use SWA CLI to deploy
npm install -g @azure/static-web-apps-cli
swa deploy ./dist --deployment-token "<token>"
```

## Multi-Environment Deployment

| Environment | Param File | Command |
|-------------|-----------|---------|
| Dev | `environments/dev.bicepparam` | `az deployment sub create ... --parameters environments/dev.bicepparam` |
| Staging | `environments/staging.bicepparam` | `az deployment sub create ... --parameters environments/staging.bicepparam` |
| Prod | `environments/prod.bicepparam` | `az deployment sub create ... --parameters environments/prod.bicepparam` |

Each environment creates isolated resource groups (`rg-cxdai-{hub|spoke}-{env}-sc`) with no cross-environment dependencies.

## Teardown

```bash
# Delete spoke resources first (has dependencies on hub DNS zones)
az group delete --name rg-cxdai-spoke-dev-sc --yes --no-wait

# Then delete hub resources
az group delete --name rg-cxdai-hub-dev-sc --yes --no-wait
```

> ⚠️ **Warning**: This permanently deletes all resources. Ensure backups exist before teardown.
