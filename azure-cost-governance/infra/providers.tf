# ──────────────────────────────────────────────────────────────────────────────
# Azure Cost Governance — Providers
# ──────────────────────────────────────────────────────────────────────────────
# Pin provider versions to avoid breaking changes in automated pipelines.

terraform {
  required_version = ">= 1.5"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
  }

  # Remote state — each environment uses its own key via -backend-config.
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate"
    container_name       = "tfstate"
    key                  = "cost-governance.tfstate"
  }
}

provider "azurerm" {
  features {}
}
