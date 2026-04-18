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