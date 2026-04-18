# 📚 Architecture & References

> Companion reference page for the **CxDAI Azure Platform**. This document consolidates the architectural design, network topology, security posture, and external references that informed the implementation.
>
> 🔙 Back to [main README](../README.md)

---

## Table of Contents

1. [Overview](#-overview)
2. [Architecture Diagram](#-architecture-diagram)
3. [Network Topology](#-network-topology)
4. [Core Components](#-core-components)
5. [Security &amp; Identity](#-security--identity)
6. [Reference Implementations](#-reference-implementations)
7. [Microsoft Documentation](#-microsoft-documentation)
8. [Tooling &amp; CLIs](#-tooling--clis)
9. [Internal Documentation](#-internal-documentation)

---

## 🧭 Overview

The **CxDAI Azure Platform** is an enterprise-grade, zero-public-access AI platform built on Azure using a **Hub-Spoke** network topology. All PaaS services are locked down behind Private Endpoints, authentication uses **User-Assigned Managed Identity + RBAC**, and developer access is brokered through an **Entra ID-authenticated P2S VPN Gateway**.

Key design goals:

- **Zero-trust networking** — no service is reachable from the public internet.
- **Modular Bicep** — every Azure resource is a reusable module under `infra/modules/`.
- **Multi-environment** — `dev`, `staging`, and `prod` parameter files drive SKU and capacity sizing.
- **Production-ready AI** — AI Foundry Hub + Project, AI Search, and Container Apps all wired into the private network.

---

## 🏗️ Architecture Diagram

```text
                                   ┌────────────────────────────┐
                                   │   Developer (Entra ID SSO) │
                                   └──────────────┬─────────────┘
                                                  │ P2S VPN (IKEv2 / OpenVPN)
                                                  ▼
 ┌────────────────────────────────────────────────────────────────────────────┐
 │                              HUB VNET (10.0.0.0/24)                         │
 │                                                                            │
 │   ┌─────────────────┐   ┌──────────────────┐   ┌──────────────────────┐    │
 │   │   VPN Gateway   │   │  Private DNS     │   │ Azure Firewall (res) │    │
 │   │   VpnGw1AZ      │   │  10 privatelink  │   │  + DNS Resolver (res)│    │
 │   └─────────────────┘   └──────────────────┘   └──────────────────────┘    │
 └──────────────────────────────────┬─────────────────────────────────────────┘
                                    │ Bidirectional VNet Peering
                                    ▼
 ┌────────────────────────────────────────────────────────────────────────────┐
 │                            SPOKE VNET (10.1.0.0/21)                        │
 │                                                                            │
 │   ┌─────────────────────────────┐    ┌──────────────────────────────────┐  │
 │   │  Container Apps Environment │    │  AI Foundry Hub + Project        │  │
 │   │  (VNet-integrated, internal)│    │  Azure AI Search                 │  │
 │   └──────────────┬──────────────┘    └──────────────┬───────────────────┘  │
 │                  │                                  │                       │
 │                  ▼                                  ▼                       │
 │   ┌────────────────────────────────────────────────────────────────────┐   │
 │   │  Private Endpoints: ACR · Key Vault · Storage (blob/file) · AI PE  │   │
 │   └────────────────────────────────────────────────────────────────────┘   │
 │                                                                            │
 │   ┌─────────────────────────────┐    ┌──────────────────────────────────┐  │
 │   │  Microsoft Fabric Capacity  │    │  Log Analytics + App Insights    │  │
 │   │  (Tenant-level Private Link)│    │                                  │  │
 │   └─────────────────────────────┘    └──────────────────────────────────┘  │
 └────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
                    ┌────────────────────────────┐
                    │  Static Web App (CDN)      │
                    │  Public frontend           │
                    │  Linked backend → ACA      │
                    └────────────────────────────┘
``` 

---

## 🌐 Network Topology

### Hub VNet — `10.0.0.0/24`

| Subnet | CIDR | Purpose |
|--------|------|---------|
| `GatewaySubnet` | `10.0.0.0/27` | P2S VPN Gateway (VpnGw1AZ) |
| `AzureFirewallSubnet` | `10.0.0.64/26` | Reserved for Azure Firewall |
| `AzureFirewallManagementSubnet` | `10.0.0.128/26` | Reserved for Firewall mgmt |
| `dns-resolver-inbound` | `10.0.0.192/28` | Reserved for DNS Private Resolver |
| `dns-resolver-outbound` | `10.0.0.208/28` | Reserved for DNS Private Resolver |

### Spoke VNet — `10.1.0.0/21`

| Subnet | CIDR | Purpose |
|--------|------|---------|
| `snet-aca` | `10.1.0.0/23` | Container Apps Environment (delegated) |
| `snet-pep` | `10.1.2.0/24` | All Private Endpoints |
| `snet-swa` | `10.1.3.0/24` | Static Web App private backend integration |

### Private DNS Zones (Hub-linked, Spoke-resolved)

- `privatelink.azurecr.io`
- `privatelink.vaultcore.azure.net`
- `privatelink.blob.core.windows.net`
- `privatelink.file.core.windows.net`
- `privatelink.search.windows.net`
- `privatelink.api.azureml.ms`
- `privatelink.notebooks.azure.net`
- `privatelink.cognitiveservices.azure.com`
- `privatelink.openai.azure.com`
- `privatelink.azurestaticapps.net`

---

## 🧩 Core Components

| Layer | Component | Bicep Module | Notes |
|-------|-----------|--------------|-------|
| Network | Hub VNet | `modules/network/hub-vnet.bicep` | Gateway, Firewall (reserved), DNS Resolver (reserved) |
| Network | Spoke VNet | `modules/network/spoke-vnet.bicep` | 3 workload subnets + NSGs |
| Network | Peering | `modules/network/vnet-peering.bicep` | Bidirectional Hub ↔ Spoke |
| Network | Private DNS | `modules/network/private-dns-zones.bicep` | 10 `privatelink.*` zones |
| Network | VPN Gateway | `modules/network/vpn-gateway.bicep` | P2S + Entra ID auth |
| Identity | UAMI | `modules/identity/managed-identity.bicep` | User-Assigned Managed Identity |
| Identity | RBAC | `modules/identity/rbac-assignments.bicep` | 7 least-privilege role assignments |
| Security | Key Vault | `modules/security/key-vault.bicep` | Standard SKU + PE |
| Storage | Storage Account | `modules/storage/storage-account.bicep` | StorageV2 + blob/file PEs |
| AI | AI Foundry Hub | `modules/ai/ai-foundry-hub.bicep` | Hub + PE |
| AI | AI Foundry Project | `modules/ai/ai-foundry-project.bicep` | Workspace project |
| AI | AI Search | `modules/ai/ai-search.bicep` | Basic/Standard + PE |
| Compute | ACR | `modules/compute/container-registry.bicep` | Premium + PE |
| Compute | Container Apps Env | `modules/compute/container-app-env.bicep` | VNet-integrated, internal |
| Compute | Container App | `modules/compute/container-app.bicep` | Internal ingress |
| Compute | Static Web App | `modules/compute/static-web-app.bicep` | Standard + linked backend |
| Data | Fabric Capacity | `modules/fabric/fabric-capacity.bicep` | F4/F8 SKU |
| Data | VNet Data Gateway | `modules/fabric/vnet-data-gateway.bicep` | Conditional |
| Observability | Monitoring | `modules/monitoring/monitoring.bicep` | Log Analytics + App Insights |

---