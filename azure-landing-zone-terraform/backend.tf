# Remote state stored in Azure Blob Storage.
# The container uses blob-level lease locking so concurrent runs cannot corrupt state.
# Backend values are injected via -backend-config at `terraform init` time,
# keeping environment-specific details out of version control.

terraform {
  backend "azurerm" {
    # Populated by -backend-config or CI/CD environment variables:
    #   resource_group_name  = "rg-terraform-state"
    #   storage_account_name = "stterraformstate"
    #   container_name       = "tfstate"
    #   key                  = "landing-zone.terraform.tfstate"
    use_oidc = true # Authenticate with the same OIDC token used by the provider
  }
}
