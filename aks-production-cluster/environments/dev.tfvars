# Development environment — relaxed settings for fast iteration.
# Uses smaller VMs, fewer nodes, and a public API server.

environment = "dev"
location    = "eastus"
project     = "aks-cluster"
owner       = "platform-engineering"
cost_center = "CC-1234"

# Networking
vnet_address_space             = ["10.0.0.0/16"]
aks_subnet_prefix              = "10.0.2.0/22"
appgw_subnet_prefix            = "10.0.1.0/24"
private_endpoint_subnet_prefix = "10.0.8.0/24"

# AKS
kubernetes_version          = "1.29"
system_node_pool_vm_size    = "Standard_D2s_v5"
system_node_pool_count      = 1
workload_node_pool_vm_size  = "Standard_D2s_v5"
workload_node_pool_min_count = 1
workload_node_pool_max_count = 3

# Public API server for easier kubectl access during development
private_cluster_enabled = false

# Key Vault
keyvault_sku = "standard"

extra_tags = {
  "temporary" = "true"
}
