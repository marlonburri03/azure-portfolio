# Azure Cloud Engineer Portfolio

<p align="center">
  <a href="https://learn.microsoft.com/en-us/certifications/azure-fundamentals/"><img src="https://img.shields.io/badge/AZ--900-Azure%20Fundamentals-0078D4?style=for-the-badge&logo=microsoftazure&logoColor=white" alt="AZ-900"></a>&nbsp;
  <a href="https://learn.microsoft.com/en-us/certifications/azure-administrator/"><img src="https://img.shields.io/badge/AZ--104-Azure%20Administrator-0078D4?style=for-the-badge&logo=microsoftazure&logoColor=white" alt="AZ-104"></a>&nbsp;
  <a href="https://learn.microsoft.com/en-us/certifications/azure-solutions-architect/"><img src="https://img.shields.io/badge/AZ--305-Solutions%20Architect%20Expert-0078D4?style=for-the-badge&logo=microsoftazure&logoColor=white" alt="AZ-305"></a>&nbsp;
  <a href="https://learn.microsoft.com/en-us/certifications/devops-engineer/"><img src="https://img.shields.io/badge/AZ--400-DevOps%20Engineer%20Expert-0078D4?style=for-the-badge&logo=microsoftazure&logoColor=white" alt="AZ-400"></a>
</p>

---

## Architecture — Hub & Spoke Topology

```mermaid
graph TD
    MG[Management Groups] --> SUB_HUB[Hub Subscription]
    MG --> SUB_SPOKE1[Spoke Subscription — Production]
    MG --> SUB_SPOKE2[Spoke Subscription — Development]

    SUB_HUB --> HUB_VNET[Hub VNet — 10.0.0.0/16]
    SUB_SPOKE1 --> SPOKE1_VNET[Spoke VNet — 10.1.0.0/16]
    SUB_SPOKE2 --> SPOKE2_VNET[Spoke VNet — 10.2.0.0/16]

    HUB_VNET --> FW[Azure Firewall]
    HUB_VNET --> VPN[VPN Gateway]
    HUB_VNET --> BASTION[Azure Bastion]

    SPOKE1_VNET -- peering --> HUB_VNET
    SPOKE2_VNET -- peering --> HUB_VNET

    FW --> ROUTE[UDR — Default Route]
    ROUTE --> SPOKE1_VNET
    ROUTE --> SPOKE2_VNET

    SPOKE1_VNET --> AKS[AKS Cluster]
    SPOKE1_VNET --> APP[App Services]
    SPOKE2_VNET --> DEV[Dev/Test Workloads]

    style MG fill:#1a1a2e,stroke:#0078D4,color:#ffffff
    style HUB_VNET fill:#16213e,stroke:#0078D4,color:#ffffff
    style SPOKE1_VNET fill:#16213e,stroke:#00bcf2,color:#ffffff
    style SPOKE2_VNET fill:#16213e,stroke:#00bcf2,color:#ffffff
    style FW fill:#4a1942,stroke:#ff4081,color:#ffffff
```

---

## Tech Stack

<p align="center">
  <strong>Azure Services</strong><br><br>
  <img src="https://skillicons.dev/icons?i=azure,kubernetes,docker&theme=dark" alt="Azure, Kubernetes, Docker" />
  <br><br>
  <img src="https://img.shields.io/badge/AKS-326CE5?style=flat-square&logo=kubernetes&logoColor=white" alt="AKS">&nbsp;
  <img src="https://img.shields.io/badge/Azure%20DevOps-0078D7?style=flat-square&logo=azuredevops&logoColor=white" alt="Azure DevOps">&nbsp;
  <img src="https://img.shields.io/badge/Azure%20Functions-0062AD?style=flat-square&logo=azurefunctions&logoColor=white" alt="Azure Functions">&nbsp;
  <img src="https://img.shields.io/badge/Azure%20Monitor-0078D4?style=flat-square&logo=microsoftazure&logoColor=white" alt="Azure Monitor">&nbsp;
  <img src="https://img.shields.io/badge/Key%20Vault-0078D4?style=flat-square&logo=microsoftazure&logoColor=white" alt="Key Vault">&nbsp;
  <img src="https://img.shields.io/badge/Container%20Registry-0078D4?style=flat-square&logo=docker&logoColor=white" alt="ACR">&nbsp;
  <img src="https://img.shields.io/badge/Virtual%20Network-0078D4?style=flat-square&logo=microsoftazure&logoColor=white" alt="VNet">&nbsp;
  <img src="https://img.shields.io/badge/Azure%20Policy-0078D4?style=flat-square&logo=microsoftazure&logoColor=white" alt="Azure Policy">&nbsp;
  <img src="https://img.shields.io/badge/Bicep-0078D4?style=flat-square&logo=microsoftazure&logoColor=white" alt="Bicep">&nbsp;
  <img src="https://img.shields.io/badge/ARM%20Templates-0078D4?style=flat-square&logo=microsoftazure&logoColor=white" alt="ARM">
</p>

<p align="center">
  <strong>Tools & Languages</strong><br><br>
  <img src="https://skillicons.dev/icons?i=terraform,githubactions,docker,python,powershell,vscode,git,linux&theme=dark" alt="Tools & Languages" />
  <br><br>
  <img src="https://img.shields.io/badge/Helm-0F1689?style=flat-square&logo=helm&logoColor=white" alt="Helm">
</p>

---

## Current Focus

🏗️ **Azure Landing Zones & Enterprise-Scale Architecture** — Production-grade multi-subscription topologies with policy-driven governance.

☸️ **AKS & Cloud-Native Workloads** — Hardened clusters, service mesh, GitOps delivery with Flux.

🔐 **DevSecOps & Zero Trust on Azure** — Identity-centric security, private endpoints everywhere, shift-left scanning in CI/CD.

---

## Featured Projects

| Repository | Description |
|---|---|
| [`azure-landing-zone-terraform`](https://github.com/azure-landing-zone-terraform) | Enterprise-scale landing zone — management groups, policy assignments, and connectivity |
| [`aks-production-cluster`](https://github.com/aks-production-cluster) | Production AKS with private API server, Workload Identity, and Azure CNI Overlay |
| [`azure-devops-cicd-pipelines`](https://github.com/azure-devops-cicd-pipelines) | Multi-stage YAML pipelines with environment approvals and template libraries |
| [`azure-serverless-event-pipeline`](https://github.com/azure-serverless-event-pipeline) | Event-driven architecture — Event Grid, Functions, Service Bus, Cosmos DB |
| [`azure-observability-stack`](https://github.com/azure-observability-stack) | Centralized monitoring with Azure Monitor, Log Analytics, Grafana, and alert routing |
| [`azure-cost-governance`](https://github.com/azure-cost-governance) | FinOps tooling — budgets, anomaly detection, and automated right-sizing recommendations |
| [`azure-zero-trust-architecture`](https://github.com/azure-zero-trust-architecture) | Zero Trust reference — Conditional Access, Private Link, NSG flow logs, and Defender for Cloud |
| [`azure-bicep-module-library`](https://github.com/azure-bicep-module-library) | Reusable Bicep modules with versioned registry publishing and validation tests |
