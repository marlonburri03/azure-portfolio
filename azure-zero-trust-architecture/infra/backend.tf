# Remote state in Azure Storage — state files contain secrets and must be
# stored in an encrypted, access-controlled backend.
terraform {
  backend "azurerm" {
    # Populated via -backend-config or CI/CD environment variables:
    #   resource_group_name  = "rg-terraform-state"
    #   storage_account_name = "stterraformstate"
    #   container_name       = "tfstate"
    #   key                  = "zero-trust.tfstate"

    # Use Azure AD auth for the backend — no storage account keys in CI
    use_oidc = true
  }
}
