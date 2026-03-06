terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azapi = {
      source  = "azure/azapi"
      version = "~> 1.10"
    }
  }

  # Remote state — each environment uses a separate state file via the
  # -backend-config flag in CI, keeping dev and prod fully isolated.
  backend "azurerm" {}
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

# azapi provider fills gaps where azurerm hasn't yet surfaced a resource
# (e.g., newer Grafana configuration options).
provider "azapi" {}
