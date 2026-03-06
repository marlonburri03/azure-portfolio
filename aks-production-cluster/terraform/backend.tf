# Remote state stored in Azure Storage with encryption at rest.
# The storage account and container must be created beforehand (bootstrap step).
# State locking is handled automatically via Azure Blob lease.
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate"
    container_name       = "tfstate"
    key                  = "aks-production-cluster.tfstate"

    # Use Azure CLI auth — no storage account key needed
    use_azuread_auth = true
  }
}
