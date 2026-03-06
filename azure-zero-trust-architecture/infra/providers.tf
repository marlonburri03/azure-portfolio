terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.80"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      # Soft-delete retention protects against accidental or malicious deletion
      purge_soft_delete_on_destroy = false
      # Recover vaults instead of failing — avoids name squatting issues
      recover_soft_deleted_key_vaults = true
    }

    resource_group {
      # Prevent accidental deletion of non-empty resource groups
      prevent_deletion_if_contains_resources = true
    }
  }
}

provider "azuread" {}
