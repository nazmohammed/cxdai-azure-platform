# Troubleshooting Guide

This document covers issues encountered during deployment and their resolutions.

---

## Deployment Errors

### 1. Container Apps Environment — Free Tier Unavailable

**Error:**
```
ManagedEnvironmentCapacityHeavyUsageError: Creating a free tier cluster is unavailable
at this time in region swedencentral.
```

**Cause:** The default Container Apps consumption-only plan uses a free AKS cluster which has capacity limits per region.

**Fix:** Add a workload profile to use the paid AKS tier:

```bicep
properties: {
  workloadProfiles: [
    {
      name: 'Consumption'
      workloadProfileType: 'Consumption'
    }
  ]
  // ... rest of config
}
```

Also set `workloadProfileName: 'Consumption'` on the Container App resource.

> **Note:** If a previous attempt created a failed environment, you must delete it before retrying:
> ```bash
> az containerapp env delete --name cae-cxdai-dev-sc --resource-group rg-cxdai-spoke-dev-sc --yes
> ```

---

### 2. Fabric Capacity — Invalid Characters in Name

**Error:**
```
BadRequest: Invalid chars in resource name
```

**Cause:** `Microsoft.Fabric/capacities` names cannot contain hyphens.

**Fix:** Use alphanumeric-only names: `fccxdaidevsc` instead of `fc-cxdai-dev-sc`.

---

### 3. Fabric Capacity — Invalid Admin Principals

**Error:**
```
BadRequest: All provided principals must be existing, user or service principals
```

**Cause:** The Fabric Capacity API expects UPN email addresses (e.g., `user@domain.com`), not Entra Object IDs.

**Fix:** Use email addresses in the `adminMembers` array:

```bicep
param fabricAdminMembers = ['admin@yourtenant.onmicrosoft.com']
```

---

### 4. VNet Data Gateway — Region Not Available

**Error:**
```
LocationNotAvailableForResourceType: The provided location 'swedencentral' is not available
for resource type 'Microsoft.PowerPlatform/enterprisePolicies'.
```

**Cause:** Power Platform enterprise policies use geo-level regions (`sweden`, `europe`, `unitedstates`), not Azure regions (`swedencentral`).

**Partial Fix:** Set location to `sweden` instead of `swedencentral`. However, cross-region subnet resolution can fail:

```
InputValidationError: The subnet for virtual network ... is null.
```

**Resolution:** The VNet Data Gateway is made conditional (`deployVnetDataGateway: false` by default). Configure it manually via the Fabric portal instead:
- Fabric Settings → Manage connections and gateways → New → Virtual Network data gateway

---

### 5. Static Web App — Region Not Available

**Error:**
```
LocationNotAvailableForResourceType: The provided location 'swedencentral' is not available
for resource type 'Microsoft.Web/staticSites'. Available: westus2, centralus, eastus2,
westeurope, eastasia.
```

**Cause:** Static Web Apps have limited deployment regions (content is CDN-global regardless).

**Fix:** Deploy SWA to `westeurope` (closest available region):

```bicep
location: 'westeurope'  // SWA resource
privateEndpointLocation: location  // PE stays in swedencentral with VNet
```

> **Important:** The Private Endpoint must be in the same region as the VNet, so the SWA module uses separate location parameters for the resource vs the PE.

---

### 6. VPN Gateway — Non-AZ SKU Rejected

**Error:**
```
NonAzSkusNotAllowedForVPNGateway: VpnGw1-5 non-AZ SKUs are no longer supported.
Only VpnGw1-5AZ SKUs can be created going forward.
```

**Cause:** Azure has deprecated non-availability-zone VPN Gateway SKUs.

**Fix:** Use `VpnGw1AZ` instead of `VpnGw1`.

---

### 7. VPN Gateway — Public IP Zones Required

**Error:**
```
VmssVpnGatewayPublicIpsMustHaveZonesConfigured: Standard Public IPs associated
with VPN Gateways with AZ VPN skus must have zones configured.
```

**Cause:** AZ-SKU VPN Gateways require zone-redundant public IPs.

**Fix:** Add `zones` to the public IP resource:

```bicep
resource publicIp 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  // ...
  zones: ['1', '2', '3']
  // ...
}
```

---

### 8. RBAC Assignments — "Unsupported" in What-If

**Symptom:** `az deployment sub what-if` shows 7 resources as "Unsupported".

**Cause:** What-if cannot pre-calculate `guid()` with `reference()` function for RBAC assignment names.

**Resolution:** This is expected behavior — RBAC assignments deploy correctly. The what-if preview simply can't evaluate runtime functions.

---

### 9. Bicepparam Relative Path Error

**Error:**
```
Error BCP258: The path "main.bicep" could not be resolved.
```

**Cause:** `.bicepparam` files are in the `environments/` subdirectory but reference `using 'main.bicep'`.

**Fix:** Use relative path: `using '../main.bicep'`

---

## Connectivity Issues

### Can't resolve private endpoints after VPN connection

**Symptoms:** `nslookup kv-cxdai-dev-sc.vault.azure.net` returns public IP instead of private IP.

**Possible causes:**
1. DNS not routing through Azure DNS
2. Private DNS zones not linked to VNet

**Fix:**
1. Check DNS zone VNet links exist:
   ```bash
   az network private-dns link vnet list \
     --zone-name privatelink.vaultcore.azure.net \
     --resource-group rg-cxdai-hub-dev-sc -o table
   ```
2. Flush local DNS cache: `ipconfig /flushdns`
3. Verify VPN is connected and you have a `172.16.0.x` IP

### VPN connection fails with Entra ID

**Possible causes:**
1. Azure VPN enterprise app not consented in tenant
2. User not assigned to the app

**Fix:**
1. Grant admin consent:
   ```
   https://login.microsoftonline.com/{tenant-id}/adminconsent?client_id=41b23e61-6c1e-4545-b367-cd054e0ed4b4
   ```
2. Verify in Entra ID → Enterprise Applications → Azure VPN → Users and groups

---

## General Tips

### Re-deploying after a failed deployment

Azure ARM deployments are idempotent — you can safely re-run the same deployment command. Existing resources will be updated (not recreated) unless there's a conflict.

**Exception:** Some resources get stuck in a `Failed` provisioning state and must be deleted before retry:
- Container Apps Environment
- VPN Gateway

### Checking deployment operation details

```bash
# List all operations for a deployment
az deployment sub operation list \
  --name "<deployment-name>" \
  --query "[?properties.provisioningState=='Failed'].{resource:properties.targetResource.resourceType, error:properties.statusMessage.error.message}" \
  -o table
```

### Monitoring resource health

```bash
# Check a specific resource's provisioning state
az resource show \
  --ids "<full-resource-id>" \
  --query "{name:name, state:properties.provisioningState}" \
  -o json
```
