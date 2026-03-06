# Azure Zero Trust Architecture

Production-grade Zero Trust network implementation on Azure — no implicit trust, every request verified, least-privilege enforced everywhere.

## Architecture

```mermaid
flowchart TB
    subgraph Internet
        User([User / Device])
    end

    subgraph "Identity Layer"
        AAD["Azure AD\nConditional Access\nMFA · Device Compliance"]
    end

    subgraph "Perimeter Layer"
        AFW["Azure Firewall\nDNAT / SNAT Rules\nThreat Intelligence"]
    end

    subgraph "Network Layer"
        subgraph "Hub VNet (10.0.0.0/16)"
            FW_SUB["AzureFirewallSubnet\n10.0.1.0/24"]
            MGMT_SUB["Management Subnet\n10.0.2.0/24\nJIT VM Access"]
        end

        subgraph "Spoke VNet (10.1.0.0/16)"
            APP_SUB["App Integration Subnet\n10.1.1.0/24"]
            PE_SUB["Private Endpoint Subnet\n10.1.2.0/24"]
            DATA_SUB["Data Subnet\n10.1.3.0/24"]
        end
    end

    subgraph "Application Layer"
        APP["App Service\nVNet Integrated\nManaged Identity"]
    end

    subgraph "Data Layer"
        KV["Key Vault\nPrivate Endpoint\nRBAC Access"]
        SA["Storage Account\nPrivate Endpoint\nNo Public Access"]
    end

    subgraph "Security & Monitoring"
        DEFENDER["Microsoft Defender\nfor Cloud\nJIT VM Access"]
        SENTINEL["Microsoft Sentinel\nSIEM · SOAR\nLog Analytics"]
        NSG_FLOW["NSG Flow Logs\nTraffic Analytics"]
    end

    User --> AAD
    AAD -->|"Verified Identity"| AFW
    AFW --> FW_SUB
    FW_SUB --> APP_SUB
    FW_SUB --> MGMT_SUB
    APP_SUB --> APP
    APP -->|"Private Endpoint"| KV
    APP -->|"Private Endpoint"| SA
    PE_SUB --- KV
    PE_SUB --- SA
    DEFENDER -.->|"Monitors"| MGMT_SUB
    SENTINEL -.->|"Ingests Logs"| NSG_FLOW
    NSG_FLOW -.->|"Flow Data"| APP_SUB
    NSG_FLOW -.->|"Flow Data"| PE_SUB

    style AAD fill:#0078d4,color:#fff
    style AFW fill:#e63946,color:#fff
    style APP fill:#2a9d8f,color:#fff
    style KV fill:#6a0dad,color:#fff
    style SA fill:#6a0dad,color:#fff
    style DEFENDER fill:#e63946,color:#fff
    style SENTINEL fill:#e63946,color:#fff
```

## Zero Trust Principles Applied

| Principle | Implementation |
|---|---|
| **Verify explicitly** | Azure AD Conditional Access with MFA, device compliance, and risk-based policies |
| **Least-privilege access** | Managed Identities with scoped RBAC; no shared keys anywhere |
| **Assume breach** | Network micro-segmentation, NSG flow logs, Microsoft Sentinel SIEM, Defender for Cloud |
| **No public endpoints** | All PaaS services accessed exclusively via Private Endpoints |
| **Perimeter defense** | Azure Firewall with DNAT/SNAT rules and threat intelligence filtering |
| **Just-in-Time access** | JIT VM Access through Microsoft Defender — no standing admin ports |

## Azure Services

- **Azure AD & Conditional Access** — Identity verification and access control
- **Azure Firewall** — Centralized network filtering with policy-based rules
- **Azure Virtual Network** — Hub-spoke topology with micro-segmented subnets
- **Azure Private Link / Endpoints** — Private connectivity to all PaaS services
- **Azure App Service** — Web application with regional VNet integration
- **Azure Key Vault** — Secrets management with private endpoint and RBAC
- **Azure Storage** — Blob storage with private endpoint and no public access
- **Microsoft Defender for Cloud** — Cloud security posture management and JIT VM access
- **Microsoft Sentinel** — SIEM/SOAR with Log Analytics workspace
- **Network Security Groups** — Subnet-level traffic filtering with flow logs

## Prerequisites

- Azure subscription with **Owner** or **Contributor + User Access Administrator** roles
- Azure AD tenant with permissions to configure Conditional Access
- Terraform >= 1.5.0
- Azure CLI >= 2.50.0
- GitHub repository with OIDC federated credentials configured

## Usage

### 1. Configure Backend

Update `infra/backend.tf` with your Azure Storage Account details for remote state.

### 2. Set Variables

```bash
# Copy and customize the environment file
cp environments/dev.tfvars environments/local.tfvars
# Edit local.tfvars with your values
```

### 3. Deploy

```bash
cd infra

# Initialize Terraform with backend
terraform init -backend-config=../environments/dev.tfvars

# Plan with environment-specific variables
terraform plan -var-file=../environments/dev.tfvars -out=tfplan

# Apply
terraform apply tfplan
```

### 4. CI/CD

Push to `main` to trigger the GitHub Actions workflow, which authenticates via OIDC (no stored secrets) and deploys through plan → approve → apply stages.

## Post-Deployment

1. **Configure Conditional Access** — Follow [`docs/conditional-access-policies.md`](docs/conditional-access-policies.md) to set up AAD policies
2. **Validate Zero Trust** — Work through [`docs/zero-trust-checklist.md`](docs/zero-trust-checklist.md)
3. **Enable Sentinel rules** — Configure analytics rules in the Sentinel workspace for threat detection

## Skills Demonstrated

- **Zero Trust Architecture** — End-to-end implementation of Microsoft's Zero Trust model
- **Network Security** — Hub-spoke topology, NSGs, Azure Firewall, Private Endpoints
- **Identity & Access** — Azure AD Conditional Access, Managed Identities, RBAC
- **Threat Detection** — Microsoft Sentinel SIEM, Defender for Cloud, JIT access
- **Infrastructure as Code** — Modular Terraform with remote state and environment separation
- **CI/CD Security** — GitHub Actions with OIDC authentication (no stored credentials)
- **Cloud Governance** — Consistent tagging, least-privilege, defense-in-depth
