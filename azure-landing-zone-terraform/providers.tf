# Pin provider versions to a minor release range so `terraform init -upgrade`
# picks up patches but never pulls a breaking change automatically.

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 2.47"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy = false # Protect secrets in production
    }
  }

  # OIDC federation — no client secret required.
  use_oidc        = true
  subscription_id = var.subscription_id
  tenant_id       = var.tenant_id
}

provider "azuread" {
  tenant_id = var.tenant_id
  use_oidc  = true
}
