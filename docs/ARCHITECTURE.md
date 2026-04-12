# Architecture & Network Design

## Overview

CxDAI uses a **Hub-Spoke** VNet topology in **Sweden Central** with all PaaS services isolated behind Private Endpoints. The architecture follows Azure Well-Architected Framework principles for security, reliability, and operational excellence.

## Network Topology

```
                              INTERNET
                                 │
                    ┌────────────┴───────────┐
                    │  Azure Static Web App   │  (Global CDN — westeurope region*)
                    │  Standard SKU           │  * SWA limited to select regions;
                    └────────────┬───────────┘    content served globally via CDN
                                 │ Linked Backend (/api/*)
    ┌────────────────────────────┼───────────────────────────────────────────┐
    │                            ▼                                           │
    │  ┌──────────────────────┐  Peering  ┌───────────────────────────────┐ │
    │  │    HUB VNET           │◄────────►│        SPOKE VNET              │ │
    │  │   10.0.0.0/24         │          │       10.1.0.0/21              │ │
    │  │                       │          │                                │ │
    │  │  ┌─────────────────┐  │          │  ┌──────────────────────────┐  │ │
    │  │  │ GatewaySubnet   │  │          │  │ container-apps-snet      │  │ │
    │  │  │ 10.0.0.192/26   │  │          │  │ 10.1.0.0/23 (512 IPs)   │  │ │
    │  │  │ P2S VPN Gateway │  │          │  │ Container Apps Env       │  │ │
    │  │  │ (VpnGw1AZ)      │  │          │  │  └─ Container App        │  │ │
    │  │  └─────────────────┘  │          │  └──────────────────────────┘  │ │
    │  │                       │          │                                │ │
    │  │  ┌─────────────────┐  │          │  ┌──────────────────────────┐  │ │
    │  │  │ Private DNS     │  │          │  │ private-endpoints-snet   │  │ │
    │  │  │ Zones (10)      │  │          │  │ 10.1.2.0/24 (256 IPs)   │  │ │
    │  │  │ Linked to both  │  │          │  │ PEs: AI Foundry, Search, │  │ │
    │  │  │ Hub + Spoke     │  │          │  │ ACR, Storage, KV, SWA    │  │ │
    │  │  └─────────────────┘  │          │  └──────────────────────────┘  │ │
    │  │                       │          │                                │ │
    │  │  ┌─────────────────┐  │          │  ┌──────────────────────────┐  │ │
    │  │  │ DNS Resolver    │  │          │  │ fabric-gateway-snet      │  │ │
    │  │  │ Inbound /26     │  │          │  │ 10.1.3.0/24 (256 IPs)   │  │ │
    │  │  │ Outbound /26    │  │          │  │ VNet Data Gateway        │  │ │
    │  │  │ (reserved)      │  │          │  │ (conditional deploy)     │  │ │
    │  │  └─────────────────┘  │          │  └──────────────────────────┘  │ │
    │  │                       │          │                                │ │
    │  │  ┌─────────────────┐  │          │  ┌──────────────────────────┐  │ │
    │  │  │ AzureFirewall   │  │          │  │ (reserved)               │  │ │
    │  │  │ Subnet /26      │  │          │  │ 10.1.4.0/22 (1024 IPs)  │  │ │
    │  │  │ (reserved)      │  │          │  │ Future expansion         │  │ │
    │  │  └─────────────────┘  │          │  └──────────────────────────┘  │ │
    │  └──────────────────────┘          └───────────────────────────────┘ │
    └────────────────────────────────────────────────────────────────────────┘
```

## IP Address Plan

### Hub VNet: `10.0.0.0/24` (256 addresses)

| Subnet | CIDR | Size | Delegation | Purpose |
|--------|------|------|------------|---------|
| `dns-resolver-inbound-snet` | `10.0.0.0/26` | 64 | `Microsoft.Network/dnsResolvers` | DNS Private Resolver inbound |
| `dns-resolver-outbound-snet` | `10.0.0.64/26` | 64 | `Microsoft.Network/dnsResolvers` | DNS Private Resolver outbound |
| `AzureFirewallSubnet` | `10.0.0.128/26` | 64 | — | Reserved for Azure Firewall |
| `GatewaySubnet` | `10.0.0.192/26` | 64 | — | P2S VPN Gateway |

### Spoke VNet: `10.1.0.0/21` (2,048 addresses)

| Subnet | CIDR | Size | Delegation | Purpose |
|--------|------|------|------------|---------|
| `container-apps-snet` | `10.1.0.0/23` | 512 | `Microsoft.App/environments` | Container Apps Environment |
| `private-endpoints-snet` | `10.1.2.0/24` | 256 | — | All PaaS Private Endpoints |
| `fabric-gateway-snet` | `10.1.3.0/24` | 256 | `Microsoft.PowerPlatform/vnetaccesslinks` | Fabric VNet Data Gateway |
| *(reserved)* | `10.1.4.0/22` | 1024 | — | Future expansion |

### VPN Client Pool: `172.16.0.0/24` (P2S clients)

## Private DNS Zones

All zones are created in the Hub Resource Group and linked to both Hub and Spoke VNets:

| DNS Zone | Service | PE Group |
|----------|---------|----------|
| `privatelink.api.azureml.ms` | AI Foundry Hub/Project | amlworkspace |
| `privatelink.notebooks.azure.net` | AI Foundry notebooks | amlworkspace |
| `privatelink.blob.core.windows.net` | Storage Account | blob |
| `privatelink.file.core.windows.net` | Storage Account | file |
| `privatelink.vaultcore.azure.net` | Key Vault | vault |
| `privatelink.search.windows.net` | AI Search | searchService |
| `privatelink.azurecr.io` | Container Registry | registry |
| `privatelink.azurestaticapps.net` | Static Web App | staticSites |
| `privatelink.analysis.windows.net` | Fabric (tenant-level) | — |
| `privatelink.cognitiveservices.azure.com` | AI Services (future) | — |

## Resource Naming Convention

Pattern: `{type}-{project}-{environment}-{region}`

| Type Prefix | Resource | Example (dev) |
|-------------|----------|---------------|
| `rg-` | Resource Group | `rg-cxdai-hub-dev-sc` |
| `vnet-hub-` | Hub VNet | `vnet-hub-cxdai-dev-sc` |
| `vnet-spoke-` | Spoke VNet | `vnet-spoke-cxdai-dev-sc` |
| `vpngw-` | VPN Gateway | `vpngw-cxdai-dev-sc` |
| `aih-` | AI Foundry Hub | `aih-cxdai-dev-sc` |
| `aip-` | AI Foundry Project | `aip-cxdai-dev-sc` |
| `srch-` | AI Search | `srch-cxdai-dev-sc` |
| `cae-` | Container Apps Env | `cae-cxdai-dev-sc` |
| `ca-` | Container App | `ca-cxdai-dev-sc` |
| `acr` | Container Registry | `acrcxdaidevsc` (no hyphens) |
| `swa-` | Static Web App | `swa-cxdai-dev-sc` |
| `fc` | Fabric Capacity | `fccxdaidevsc` (no hyphens) |
| `kv-` | Key Vault | `kv-cxdai-dev-sc` |
| `st` | Storage Account | `stcxdaidevsc` (no hyphens) |
| `law-` | Log Analytics | `law-cxdai-dev-sc` |
| `appi-` | Application Insights | `appi-cxdai-dev-sc` |
| `uami-` | Managed Identity | `uami-cxdai-dev-sc` |
| `pe-` | Private Endpoint | `pe-kv-cxdai-dev-sc` |

> **Note:** ACR, Storage, and Fabric capacity names cannot contain hyphens.

## RBAC Role Assignments

All roles are assigned to the User-Assigned Managed Identity (`uami-cxdai-{env}-sc`):

| Role | Built-in Role ID | Scope | Purpose |
|------|-----------------|-------|---------|
| AcrPull | `7f951dda-4ed3-4680-a7ca-43fe172d538d` | Container Registry | Pull container images |
| Storage Blob Data Contributor | `ba92f5b4-2d11-453d-a403-e96b0029c9fe` | Storage Account | Read/write blob data |
| Key Vault Secrets User | `4633458b-17de-408a-b874-0445c86b69e6` | Key Vault | Read secrets |
| Cognitive Services OpenAI User | `5e0bd9bd-7b93-4f28-af87-19fc36ad61bd` | AI Foundry Hub | Model inference |
| Search Index Data Reader | `1407120a-92aa-4202-b7e9-c0e197c71c8f` | AI Search | Query search indexes |
| Search Service Contributor | `7ca78c08-252a-4471-8644-bb5ff32d4ba0` | AI Search | Manage search service |

## Deployment Phases

```
Phase 1: Foundation ─── Resource Groups + UAMI + Monitoring
         │
Phase 2: Networking ─── Hub VNet + Spoke VNet + Peering + DNS Zones + VPN Gateway
         │
Phase 3: Security ──── Key Vault (PE) + Storage Account (blob/file PEs)
         │
Phase 4: AI Services ── AI Foundry Hub (PE) + Project + AI Search (PE)
         │
Phase 5: Compute ───── ACR (PE) + Container Apps Env + Container App + SWA (PE)
         │
Phase 6: Fabric ────── Fabric Capacity + VNet Data Gateway (conditional)
         │
Phase 7: RBAC ──────── All role assignments for UAMI
```

## VPN Access

The P2S VPN Gateway (`VpnGw1AZ`) provides secure developer access to all private resources:

- **Auth**: Entra ID (Azure AD) SSO — no certificates to manage
- **Protocol**: OpenVPN
- **Client Pool**: `172.16.0.0/24`
- **Zone-redundant**: Deployed across AZs 1, 2, 3

Once connected, developers can access all Private Endpoints directly from their local machine (VS Code, CLI, browser).

## Future Enhancements

- [ ] Azure Firewall in Hub VNet for egress filtering
- [ ] Azure DNS Private Resolver for hybrid DNS
- [ ] S2S VPN for office network connectivity
- [ ] Azure Bastion for emergency VM access
- [ ] Azure Front Door for global load balancing
- [ ] ExpressRoute for dedicated on-premises connectivity
