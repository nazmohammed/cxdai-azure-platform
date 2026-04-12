# Architecture Decision Records (ADRs)

This document captures the key architectural decisions made during the design and implementation of the CxDAI Azure platform.

---

## ADR-001: Hub-Spoke VNet Topology

**Status:** Accepted

**Context:** We need to deploy 6+ PaaS services with private networking. Options considered:
1. Single VNet with multiple subnets
2. Hub-Spoke topology
3. Virtual WAN

**Decision:** Hub-Spoke topology.

**Rationale:**
- Clean separation: shared services (DNS, future firewall, VPN) in Hub; workloads in Spoke
- Future-proof: can add more Spokes (e.g., for staging/prod in separate VNets) without changing Hub
- Well-established Azure pattern with strong documentation
- Virtual WAN is overkill for a single-spoke topology

---

## ADR-002: Hub VNet /24, Spoke VNet /21

**Status:** Accepted

**Context:** The user initially had a /16 Hub VNet, which was oversized. We needed right-sized address spaces.

**Decision:**
- Hub: `10.0.0.0/24` (256 IPs) — 4 × /26 subnets
- Spoke: `10.1.0.0/21` (2,048 IPs) — workload subnets with room to grow

**Rationale:**
- Hub only needs DNS resolver, firewall, and gateway subnets — /24 is sufficient
- Spoke needs Container Apps (/23 minimum), private endpoints, and Fabric gateway
- /21 for Spoke provides 1,024 IPs reserved for future expansion
- Non-overlapping with VPN client pool (172.16.0.0/24)

---

## ADR-003: All PaaS Services Private Endpoint Only

**Status:** Accepted

**Context:** Should services have public endpoints with IP restrictions, or be fully private?

**Decision:** `publicNetworkAccess: Disabled` on all PaaS services with Private Endpoints.

**Rationale:**
- Zero-trust security model — no public attack surface
- All access via VNet (Private Endpoints) or VPN
- Storage uses `allowSharedKeyAccess: false` — RBAC only
- Trade-off: requires VPN for developer access (acceptable for enterprise)

---

## ADR-004: User-Assigned Managed Identity (UAMI) over System-Assigned

**Status:** Accepted

**Context:** Services need identity for cross-resource authentication. Options: System-Assigned MI per resource, or shared UAMI.

**Decision:** Single User-Assigned Managed Identity shared across workloads.

**Rationale:**
- Predictable identity lifecycle (independent of resource lifecycle)
- Single set of RBAC assignments to manage
- Can be referenced before the consuming resource exists (better for Bicep dependency ordering)
- System-Assigned is fine for individual services, but UAMI is cleaner for multi-service orchestration

---

## ADR-005: AI Foundry Hub + Project Model

**Status:** Accepted

**Context:** Azure AI Foundry can be deployed as standalone workspace or Hub+Project hierarchy.

**Decision:** Hub + Project model (`kind: Hub` + `kind: Project`).

**Rationale:**
- Hub centralizes shared resources (Storage, Key Vault, ACR, App Insights)
- Projects provide isolated workspaces for different teams/use cases
- Network settings (private endpoint) are configured once at Hub level
- Projects inherit Hub networking — no duplicate PE configuration
- Aligns with enterprise multi-team usage patterns

---

## ADR-006: Static Web App in westeurope (not swedencentral)

**Status:** Accepted

**Context:** `Microsoft.Web/staticSites` is only available in 5 regions: `westus2, centralus, eastus2, westeurope, eastasia`.

**Decision:** Deploy SWA resource to `westeurope`; Private Endpoint stays in `swedencentral`.

**Rationale:**
- SWA content is served globally via Azure CDN — the "region" only affects the management plane
- `westeurope` is geographically closest to Sweden Central
- The Private Endpoint must be in the same region as the VNet (`swedencentral`)
- Separate `location` and `privateEndpointLocation` parameters handle this cleanly

---

## ADR-007: P2S VPN Gateway for Developer Access

**Status:** Accepted

**Context:** All resources are private — developers need a way to access them. Options:
1. Azure Bastion + Jump Box VM
2. P2S VPN Gateway
3. S2S VPN Gateway
4. ExpressRoute

**Decision:** P2S VPN Gateway with Entra ID authentication (`VpnGw1AZ`).

**Rationale:**
- No on-premises VPN device available (rules out S2S)
- Best developer experience — access from local machine (VS Code, CLI, browser)
- Entra ID SSO — no certificates to manage
- Zone-redundant (AZ SKU) for reliability
- Can add S2S tunnel to the same gateway later if needed
- Cost: ~$140/month (acceptable for enterprise)

---

## ADR-008: Container Apps with Workload Profiles

**Status:** Accepted

**Context:** Container Apps can run in consumption-only or workload-profile mode.

**Decision:** Workload-profile mode with `Consumption` profile.

**Rationale:**
- Consumption-only mode uses free-tier AKS clusters which have regional capacity limits
- Sweden Central frequently hits `ManagedEnvironmentCapacityHeavyUsageError` on free tier
- Workload-profile mode with `Consumption` profile provides the same serverless scaling but on paid AKS infrastructure
- More reliable provisioning and better SLA
- Still pay-per-use (no idle cost beyond the AKS management fee)

---

## ADR-009: Fabric VNet Data Gateway as Conditional Deployment

**Status:** Accepted

**Context:** `Microsoft.PowerPlatform/enterprisePolicies` has limited region support (geo-level, not Azure regions) and cross-region subnet resolution issues.

**Decision:** VNet Data Gateway module is conditional (`deployVnetDataGateway: false` by default).

**Rationale:**
- The enterprise policy API uses geo-level regions (`sweden` not `swedencentral`)
- Cross-region subnet resolution fails silently
- Manual setup via Fabric portal is more reliable
- Fabric Capacity itself deploys fine via Bicep
- Private Link for Fabric is a tenant-level admin setting (portal only)

---

## ADR-010: Fabric Admin Members as UPNs (not Object IDs)

**Status:** Accepted

**Context:** `Microsoft.Fabric/capacities` API rejected Entra Object IDs with "principals must be existing" error.

**Decision:** Use UPN email addresses for `administration.members`.

**Rationale:**
- Fabric Capacity API expects email addresses (UPNs), not Object IDs
- This is inconsistent with most Azure APIs (which use Object IDs) but is how the Fabric RP works
- Documented in param files for clarity

---

## ADR-011: Modular Bicep with Subscription-Level Orchestration

**Status:** Accepted

**Context:** How to structure the IaC — single file, resource-group-level modules, or subscription-level orchestration?

**Decision:** Subscription-level `main.bicep` with resource-group-scoped modules.

**Rationale:**
- `targetScope = 'subscription'` allows creating resource groups in the same deployment
- Modules are scoped to specific resource groups (`scope: hubRg` / `scope: spokeRg`)
- Single entry point for all environments — just swap the `.bicepparam` file
- Clear phase ordering via implicit Bicep dependencies
- No need for deployment scripts or multi-step CI/CD pipelines

---

## ADR-012: Private DNS Zones in Hub Resource Group

**Status:** Accepted

**Context:** Private DNS zones can live in Hub RG, Spoke RG, or a dedicated DNS RG.

**Decision:** Hub Resource Group.

**Rationale:**
- DNS is a shared/infrastructure service — belongs with Hub networking
- Zones are linked to both Hub and Spoke VNets
- Single management point for all DNS zones
- If multiple Spokes are added later, they share the same DNS zones via additional VNet links
