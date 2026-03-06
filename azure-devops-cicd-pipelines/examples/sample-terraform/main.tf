# =============================================================================
# Sample Terraform Configuration
# =============================================================================
# Demonstrates the resource patterns that work with the CI/CD pipelines
# in this repository. Includes proper tagging, OIDC backend config, and
# the module structure expected by the pipeline templates.
# =============================================================================

terraform {
  required_version = ">= 1.7.0"

  # Backend is configured dynamically by the pipeline via -backend-config flags
  # This allows the same code to target different state files per environment
  backend "azurerm" {}

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
  }
}

# OIDC authentication — the provider reads ARM_* environment variables
# set by the pipeline (ARM_USE_OIDC=true, ARM_CLIENT_ID, etc.)
provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy = false
    }
  }
}

# Local values for consistent tagging across all resources
locals {
  common_tags = {
    Environment = var.environment
    Owner       = var.owner
    CostCenter  = var.cost_center
    Project     = var.project_name
    ManagedBy   = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location
  tags     = local.common_tags
}

# ---------------------------------------------------------------------------
# Azure Container Registry — stores Docker images built by the pipeline
# ---------------------------------------------------------------------------
resource "azurerm_container_registry" "acr" {
  name                = replace("acr${var.project_name}${var.environment}", "-", "")
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = var.environment == "prod" ? "Premium" : "Standard"
  admin_enabled       = false # Use OIDC/managed identity instead of admin credentials
  tags                = local.common_tags

  # Geo-replication for production — ensures low-latency pulls from any region
  dynamic "georeplications" {
    for_each = var.environment == "prod" ? var.acr_replication_locations : []
    content {
      location = georeplications.value
      tags     = local.common_tags
    }
  }
}

# ---------------------------------------------------------------------------
# Azure Kubernetes Service — deployment target for containerized workloads
# ---------------------------------------------------------------------------
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  dns_prefix          = "${var.project_name}-${var.environment}"
  kubernetes_version  = var.kubernetes_version
  tags                = local.common_tags

  default_node_pool {
    name                = "system"
    vm_size             = var.aks_node_vm_size
    node_count          = var.aks_node_count
    vnet_subnet_id      = azurerm_subnet.aks.id
    os_disk_size_gb     = 128
    max_pods            = 50
    tags                = local.common_tags
  }

  # Workload Identity — allows pods to authenticate to Azure via OIDC
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "calico"
    load_balancer_sku = "standard"
    service_cidr      = "10.1.0.0/16"
    dns_service_ip    = "10.1.0.10"
  }
}

# ---------------------------------------------------------------------------
# Networking — VNet and Subnet for AKS
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.project_name}-${var.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = [var.vnet_address_space]
  tags                = local.common_tags
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.aks_subnet_prefix]
}

# ---------------------------------------------------------------------------
# Role Assignment — allow AKS to pull images from ACR
# ---------------------------------------------------------------------------
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

# ---------------------------------------------------------------------------
# Outputs — consumed by downstream pipeline stages
# ---------------------------------------------------------------------------
output "resource_group_name" {
  value = azurerm_resource_group.main.name
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "aks_cluster_id" {
  value = azurerm_kubernetes_cluster.aks.id
}
