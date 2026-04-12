# CxDAI Azure Platform

Enterprise-grade Azure infrastructure for the CxDAI AI platform, deployed behind a secure Hub-Spoke VNet using modular Bicep templates.

## 🏗️ Architecture

```
                         ┌──────────────────────┐
                         │  Static Web App (CDN) │
                         └──────────┬───────────┘
                                    │ Linked Backend (/api/*)
    ┌───────────────────────────────┼──────────────────────────────────────┐
    │                               ▼                                      │
    │  ┌─────────────────┐  Peering  ┌────────────────────────────────┐   │
    │  │    HUB VNET      │◄────────►│         SPOKE VNET              │   │
    │  │   10.0.0.0/24    │          │        10.1.0.0/21              │   │
    │  │                  │          │                                  │   │
    │  │ • Private DNS    │          │ • Container Apps (internal)      │   │
    │  │ • VPN Gateway    │          │ • AI Foundry Hub + Project       │   │
    │  │ • DNS Resolver   │          │ • AI Search                      │   │
    │  │   (reserved)     │          │ • ACR, Storage, Key Vault        │   │
    │  │ • Azure Firewall │          │ • Fabric Capacity                │   │
    │  │   (reserved)     │          │ • All Private Endpoints          │   │
    │  └─────────────────┘          └────────────────────────────────┘   │
    └──────────────────────────────────────────────────────────────────────┘
```

## 📦 Services Deployed

| Service | Resource | Access |
|---------|----------|--------|
| **Azure AI Foundry** | Hub + Project | Private Endpoint only |
| **Azure AI Search** | Basic/Standard | Private Endpoint only |
| **Azure Container Apps** | VNet-integrated, internal | Via SWA linked backend |
| **Azure Container Registry** | Premium | Private Endpoint only |
| **Azure Static Web App** | Standard (CDN-global) | Public frontend, private backend |
| **Microsoft Fabric** | F4/F8 Capacity | Tenant-level Private Link |
| **Azure Key Vault** | Standard | Private Endpoint only |
| **Azure Storage** | StorageV2 (blob + file PEs) | Private Endpoint only |
| **VPN Gateway** | VpnGw1AZ (P2S + Entra ID) | Secure developer access |

## 🚀 Quick Start

### Prerequisites

- [Azure CLI](https://docs.microsoft.com/cli/azure/install-azure-cli) v2.50+
- [Bicep CLI](https://docs.microsoft.com/azure/azure-resource-manager/bicep/install) v0.40+
- Azure subscription with Owner/Contributor role
- `Microsoft.Fabric` resource provider registered

### Deploy to Dev

```bash
az login
az account set --subscription "<your-subscription-id>"

cd infra
az deployment sub create \
  --name "cxdai-dev-deploy" \
  --location swedencentral \
  --template-file main.bicep \
  --parameters environments/dev.bicepparam
```

### Deploy to Staging / Prod

```bash
# Staging
az deployment sub create \
  --name "cxdai-staging-deploy" \
  --location swedencentral \
  --template-file main.bicep \
  --parameters environments/staging.bicepparam

# Production
az deployment sub create \
  --name "cxdai-prod-deploy" \
  --location swedencentral \
  --template-file main.bicep \
  --parameters environments/prod.bicepparam
```

### Connect via P2S VPN

1. Install [Azure VPN Client](https://aka.ms/azvpnclientdownload)
2. Download VPN profile: Portal → `vpngw-cxdai-dev-sc` → Point-to-site configuration → Download VPN client
3. Import profile XML into Azure VPN Client
4. Connect with your Entra ID credentials
5. Access all private endpoints from your local machine

## 📁 Project Structure

```
infra/
├── main.bicep                              # Subscription-level orchestrator
├── environments/
│   ├── dev.bicepparam                      # Dev parameters (F4, basic search)
│   ├── staging.bicepparam                  # Staging parameters (F4, standard search)
│   └── prod.bicepparam                     # Prod parameters (F8, standard2 search)
├── modules/
│   ├── network/
│   │   ├── hub-vnet.bicep                  # Hub VNet + DNS/Firewall/Gateway subnets
│   │   ├── spoke-vnet.bicep                # Spoke VNet + 3 workload subnets + NSGs
│   │   ├── vnet-peering.bicep              # Bidirectional Hub↔Spoke peering
│   │   ├── spoke-to-hub-peering.bicep      # Cross-RG peering helper
│   │   ├── private-dns-zones.bicep         # 10 privatelink.* DNS zones
│   │   └── vpn-gateway.bicep              # P2S VPN Gateway with Entra ID auth
│   ├── identity/
│   │   ├── managed-identity.bicep          # User-Assigned Managed Identity
│   │   └── rbac-assignments.bicep          # 7 RBAC role assignments
│   ├── monitoring/
│   │   └── monitoring.bicep                # Log Analytics + Application Insights
│   ├── security/
│   │   └── key-vault.bicep                 # Key Vault + Private Endpoint
│   ├── storage/
│   │   └── storage-account.bicep           # Storage + blob/file PEs
│   ├── ai/
│   │   ├── ai-foundry-hub.bicep            # AI Foundry Hub + PE
│   │   ├── ai-foundry-project.bicep        # AI Foundry Project
│   │   └── ai-search.bicep                 # AI Search + PE
│   ├── compute/
│   │   ├── container-registry.bicep        # ACR Premium + PE
│   │   ├── container-app-env.bicep         # Container Apps Env (VNet-integrated)
│   │   ├── container-app.bicep             # Container App (internal ingress)
│   │   └── static-web-app.bicep            # SWA Standard + linked backend + PE
│   └── fabric/
│       ├── fabric-capacity.bicep           # Fabric F SKU capacity
│       └── vnet-data-gateway.bicep         # VNet Data Gateway (conditional)
docs/
├── ARCHITECTURE.md                         # Detailed architecture & network design
├── DEPLOYMENT.md                           # Step-by-step deployment guide
├── TROUBLESHOOTING.md                      # Common issues & resolutions
└── DECISIONS.md                            # Architecture Decision Records (ADRs)
```

## 🔒 Security Model

- **Zero public access** — all PaaS services have `publicNetworkAccess: Disabled`
- **Private Endpoints** — every service accessible only via PE in the Spoke VNet
- **RBAC-only auth** — User-Assigned Managed Identity with least-privilege roles
- **No shared keys** — `allowSharedKeyAccess: false` on storage
- **NSGs** — deny-all-inbound default with explicit allow rules per subnet
- **P2S VPN** — Entra ID SSO for developer access to private resources

## 🌍 Multi-Environment Support

| Parameter | Dev | Staging | Prod |
|-----------|-----|---------|------|
| Fabric SKU | F4 | F4 | F8 |
| AI Search SKU | basic | standard | standard2 |
| Container App CPU | 0.5 | 1.0 | 2.0 |
| Container App Memory | 1Gi | 2Gi | 4Gi |

## 📖 Documentation

- [Architecture & Network Design](docs/ARCHITECTURE.md)
- [Deployment Guide](docs/DEPLOYMENT.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Architecture Decision Records](docs/DECISIONS.md)

## 📄 License

Private — Internal use only.
