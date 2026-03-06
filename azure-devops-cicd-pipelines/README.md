# Azure DevOps CI/CD Pipelines

Production-ready, reusable CI/CD pipelines for **GitHub Actions** and **Azure DevOps** that deploy Azure infrastructure using Terraform and Bicep — with zero stored credentials.

[![Terraform](https://img.shields.io/badge/Terraform-1.7+-623CE4?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Azure](https://img.shields.io/badge/Azure-Cloud-0078D4?logo=microsoftazure&logoColor=white)](https://azure.microsoft.com/)
[![OIDC](https://img.shields.io/badge/Auth-OIDC%20Federation-success)](https://docs.github.com/en/actions/deployment/security-hardening-your-deployments/about-security-hardening-with-openid-connect)
[![Security](https://img.shields.io/badge/Security-Checkov%20%7C%20tfsec%20%7C%20MSDO-red)](https://www.checkov.io/)

---

## Architecture & Pipeline Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Developer Workflow                               │
│                                                                         │
│  ┌──────────┐    ┌──────────┐    ┌───────────┐    ┌─────────────────┐  │
│  │  Commit   │───▶│   PR     │───▶│  Review   │───▶│  Merge to main  │  │
│  │  & Push   │    │  Created │    │  Plan +   │    │                 │  │
│  └──────────┘    └──────────┘    │  Security  │    └────────┬────────┘  │
│                                  └───────────┘             │            │
└────────────────────────────────────────────────────────────┼────────────┘
                                                             │
                    ┌────────────────────────────────────────▼──────────┐
                    │              CI/CD Pipeline                        │
                    │                                                    │
                    │  ┌────────────────────────────────────────────┐   │
                    │  │  Stage 1: Validate & Security Scan         │   │
                    │  │  ┌──────────┐ ┌────────┐ ┌─────────────┐  │   │
                    │  │  │ tf fmt   │ │Checkov │ │   tfsec     │  │   │
                    │  │  │ tf init  │ │  scan  │ │   scan      │  │   │
                    │  │  │ tf valid │ │        │ │             │  │   │
                    │  │  └──────────┘ └────────┘ └─────────────┘  │   │
                    │  └───────────────────┬────────────────────────┘   │
                    │                      │                            │
                    │  ┌───────────────────▼────────────────────────┐   │
                    │  │  Stage 2: Deploy to Dev          (auto)    │   │
                    │  │  ┌─────────────┐  ┌─────────────────────┐  │   │
                    │  │  │ OIDC Login  │─▶│ Terraform Plan +    │  │   │
                    │  │  │ (no creds)  │  │ Apply               │  │   │
                    │  │  └─────────────┘  └─────────────────────┘  │   │
                    │  └───────────────────┬────────────────────────┘   │
                    │                      │                            │
                    │  ┌───────────────────▼────────────────────────┐   │
                    │  │  Stage 3: Deploy to Staging   (approval)   │   │
                    │  │  ┌─────────┐  ┌─────────────────────────┐  │   │
                    │  │  │ Manual  │─▶│ Terraform Plan + Apply  │  │   │
                    │  │  │Approval │  │                         │  │   │
                    │  │  └─────────┘  └─────────────────────────┘  │   │
                    │  └───────────────────┬────────────────────────┘   │
                    │                      │                            │
                    │  ┌───────────────────▼────────────────────────┐   │
                    │  │  Stage 4: Deploy to Production (approval)  │   │
                    │  │  ┌─────────┐  ┌─────────────────────────┐  │   │
                    │  │  │ 2-Person│─▶│ Terraform Plan + Apply  │  │   │
                    │  │  │ Review  │  │ (business hours only)   │  │   │
                    │  │  └─────────┘  └─────────────────────────┘  │   │
                    │  └────────────────────────────────────────────┘   │
                    └──────────────────────────────────────────────────┘

                    ┌──────────────────────────────────────────────────┐
                    │              Azure Resources Deployed             │
                    │                                                   │
                    │  ┌─────────┐  ┌─────────┐  ┌──────────────────┐  │
                    │  │  AKS    │  │   ACR   │  │  VNet / Subnet   │  │
                    │  │ Cluster │◀─│Registry │  │  NSG / Route     │  │
                    │  └─────────┘  └─────────┘  └──────────────────┘  │
                    └──────────────────────────────────────────────────┘
```

## Repository Structure

```
azure-devops-cicd-pipelines/
├── github-actions/                    # GitHub Actions reusable workflows
│   ├── terraform-plan-apply.yml       # Terraform plan/apply with PR comments
│   ├── docker-build-push-acr.yml      # Docker build & push to ACR
│   ├── security-scanning.yml          # Checkov, tfsec, Defender for DevOps
│   └── bicep-deploy.yml              # Azure Bicep deployment pipeline
├── azure-devops/                      # Azure DevOps YAML pipelines
│   ├── terraform-pipeline.yml         # Multi-stage: dev → staging → prod
│   ├── docker-pipeline.yml            # Docker build with canary deployment
│   └── templates/                     # Reusable pipeline templates
│       ├── terraform-plan.yml         # Plan and publish artifact
│       ├── terraform-apply.yml        # Apply from saved plan artifact
│       └── security-scan.yml          # Checkov + tfsec template
├── scripts/                           # Supporting automation scripts
│   ├── pr-comment.sh                  # Post terraform plan as PR comment
│   └── validate-tags.py              # Validate Azure resource tags
└── examples/                          # Sample IaC configurations
    ├── sample-terraform/              # Terraform example (ACR + AKS)
    │   ├── main.tf
    │   └── variables.tf
    └── sample-bicep/                  # Bicep alternative
        └── main.bicep
```

## Azure Services

| Service | Purpose |
|---------|---------|
| **Azure Kubernetes Service (AKS)** | Container orchestration with Workload Identity |
| **Azure Container Registry (ACR)** | Private Docker image registry with geo-replication |
| **Azure Storage** | Terraform remote state backend |
| **Azure Active Directory** | Workload Identity Federation (OIDC) |
| **Microsoft Defender for Cloud** | Security posture management and DevOps scanning |
| **Azure Virtual Network** | Network isolation with NSGs and route tables |

## Key Features

### 🔐 OIDC Federated Credentials (Zero Stored Secrets)

All pipelines authenticate to Azure using **OpenID Connect (OIDC)** federation — no client secrets or certificates are stored anywhere:

```yaml
# GitHub Actions — exchanges a GitHub JWT for an Azure access token
- uses: azure/login@v2
  with:
    client-id: ${{ vars.AZURE_CLIENT_ID }}    # Not a secret — public identifier
    tenant-id: ${{ vars.AZURE_TENANT_ID }}
    subscription-id: ${{ vars.AZURE_SUBSCRIPTION_ID }}
```

### 📋 Plan-as-PR-Comment

Terraform plan output is posted directly to the pull request, giving reviewers full visibility into infrastructure changes before approval:

- Updates existing comments on re-push (avoids PR clutter)
- Truncates large plans gracefully (GitHub's 65KB comment limit)
- Shows environment, working directory, and actor

### 🛡️ Multi-Layer Security Scanning

Three complementary scanners run on every PR:

| Scanner | Focus | Coverage |
|---------|-------|----------|
| **Checkov** | Policy-as-code engine | Terraform, ARM, K8s, Dockerfile |
| **tfsec** | Terraform deep analysis | Azure-specific security rules |
| **Microsoft Defender for DevOps** | Cloud-native scanning | Integrates with Defender for Cloud dashboard |

### 🚀 Progressive Deployment with Approval Gates

```
dev (auto) → staging (1 reviewer) → production (2 reviewers + business hours)
```

- **GitHub Actions**: Uses [GitHub Environments](https://docs.github.com/en/actions/deployment/targeting-different-environments) with required reviewers and deployment branch policies
- **Azure DevOps**: Uses [Environments with Approval Checks](https://learn.microsoft.com/en-us/azure/devops/pipelines/process/approvals) and exclusive locks

## Prerequisites

### Azure Setup

1. **Register an Azure AD Application** for each environment (dev, staging, prod)
2. **Configure Federated Credentials** pointing to your GitHub org/repo:
   ```bash
   az ad app federated-credential create \
     --id <app-object-id> \
     --parameters '{
       "name": "github-main",
       "issuer": "https://token.actions.githubusercontent.com",
       "subject": "repo:<org>/<repo>:ref:refs/heads/main",
       "audiences": ["api://AzureADTokenExchange"]
     }'
   ```
3. **Create a Storage Account** for Terraform remote state
4. **Grant RBAC roles** to the app registration (Contributor + User Access Administrator)

### GitHub Setup

1. Create **Environments** (dev, staging, production) under Settings → Environments
2. Add **required reviewers** for staging and production environments
3. Set **repository variables** (not secrets — OIDC uses public identifiers):
   - `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`
   - `TF_STATE_RG`, `TF_STATE_SA`
   - `ACR_NAME`, `AKS_RESOURCE_GROUP`, `AKS_CLUSTER_NAME`

### Azure DevOps Setup

1. Create **Service Connections** using Workload Identity Federation
2. Create **Environments** (dev, staging, production) with approval checks
3. Create **Variable Groups** linked to Azure Key Vault

## Usage

### GitHub Actions — Terraform

Copy the workflow to your repository:

```bash
cp github-actions/terraform-plan-apply.yml .github/workflows/
```

Trigger on a pull request to see the plan as a PR comment, then merge to deploy.

### GitHub Actions — Docker

```bash
cp github-actions/docker-build-push-acr.yml .github/workflows/
```

### Azure DevOps — Multi-Stage Terraform

Import the pipeline in Azure DevOps → Pipelines → New Pipeline → Existing YAML:

```
azure-devops/terraform-pipeline.yml
```

### Validate Resource Tags

Run the tag validation script in CI or locally:

```bash
# From a terraform plan
terraform show -json tfplan > plan.json
python scripts/validate-tags.py --plan plan.json

# From terraform state
terraform state pull > state.json
python scripts/validate-tags.py --state state.json
```

## Skills Demonstrated

| Category | Technologies & Practices |
|----------|------------------------|
| **CI/CD Platforms** | GitHub Actions, Azure DevOps Pipelines |
| **Infrastructure as Code** | Terraform (HCL), Azure Bicep (ARM DSL) |
| **Security** | OIDC federation, Checkov, tfsec, Microsoft Defender for DevOps, Trivy |
| **Containers** | Docker multi-stage builds, ACR, AKS deployment, canary releases |
| **Cloud Architecture** | Multi-environment promotion, approval gates, RBAC, state management |
| **DevOps Practices** | GitOps, plan-as-PR-comment, reusable templates, policy-as-code |
| **Scripting** | Bash (GitHub API integration), Python (tag governance) |

## License

MIT
