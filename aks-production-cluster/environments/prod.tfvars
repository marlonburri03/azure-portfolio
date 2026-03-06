# Production environment — hardened settings with private networking,
# larger node pools, and premium Key Vault for HSM-backed keys.

environment = "prod"
location    = "eastus"
project     = "aks-cluster"
owner       = "platform-engineering"
cost_center = "CC-1234"

# Networking
vnet_address_space             = ["10.0.0.0/16"]
aks_subnet_prefix              = "10.0.2.0/22"
appgw_subnet_prefix            = "10.0.1.0/24"
private_endpoint_subnet_prefix = "10.0.8.0/24"

# AKS — production-grade sizing and scaling
kubernetes_version          = "1.29"
system_node_pool_vm_size    = "Standard_D4s_v5"
system_node_pool_count      = 2
workload_node_pool_vm_size  = "Standard_D4s_v5"
workload_node_pool_min_count = 2
workload_node_pool_max_count = 10

# Private API server — accessible only via VPN or jump-box
private_cluster_enabled = true

# Premium SKU enables HSM-backed keys for regulatory compliance
keyvault_sku = "premium"

extra_tags = {
  "compliance" = "soc2"
  "dr-tier"    = "tier-1"
}
