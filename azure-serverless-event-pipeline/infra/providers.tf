# ---------------------------------------------------------------------------
# providers.tf — Provider versions and Terraform backend configuration
# ---------------------------------------------------------------------------
# Pin provider versions to avoid breaking changes from upstream releases.
# The azurerm provider requires `features {}` even when empty.
# ---------------------------------------------------------------------------

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.90"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
  }

  # Remote state in Azure Storage — the backend storage account is provisioned
  # outside this configuration (see README).  Each environment uses a separate
  # state file via the `key` attribute set in CI.
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate"
    container_name       = "tfstate"
    key                  = "serverless-event-pipeline.tfstate"
    use_oidc             = true # Authenticate with GitHub OIDC — no stored secrets
  }
}

provider "azurerm" {
  features {
    # Purge Key Vault on destroy so CI environments can be recycled cleanly.
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }

  # Use OIDC in CI; falls back to az-cli locally.
  use_oidc = true
}

provider "azuread" {}
