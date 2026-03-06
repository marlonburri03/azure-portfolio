# --------------------------------------------------------------------------
# AKS Cluster
# --------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "aks-${var.environment}"
  kubernetes_version  = var.kubernetes_version
  tags                = local.tags

  # Private cluster keeps the API server off the public internet.
  # Access is via VPN, ExpressRoute, or a jump-box inside the VNet.
  private_cluster_enabled = var.private_cluster_enabled

  # Use a pre-created user-assigned identity so permissions can be
  # granted before the cluster is provisioned (avoids race conditions).
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks.id]
  }

  # --------------------------------------------------------------------------
  # System Node Pool — dedicated to kube-system workloads
  # --------------------------------------------------------------------------
  default_node_pool {
    name                 = "system"
    vm_size              = var.system_node_pool_vm_size
    node_count           = var.system_node_pool_count
    vnet_subnet_id       = azurerm_subnet.aks.id
    os_disk_type         = "Ephemeral" # Faster I/O and no storage cost
    os_disk_size_gb      = 128
    max_pods             = 110         # Azure CNI Overlay supports higher pod density
    zones                = ["1", "2", "3"]
    temporary_name_for_rotation = "systmp"

    # CriticalAddonsOnly taint ensures only kube-system pods schedule here,
    # keeping system workloads isolated from application resource pressure.
    only_critical_addons_enabled = true

    node_labels = {
      "nodepool" = "system"
    }

    upgrade_settings {
      max_surge = "33%"
    }

    tags = local.tags
  }

  # --------------------------------------------------------------------------
  # Networking — Azure CNI Overlay
  # --------------------------------------------------------------------------
  network_profile {
    # CNI Overlay assigns pods IPs from a separate overlay CIDR, decoupling
    # pod IP space from the VNet. This avoids subnet exhaustion at scale.
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "calico" # Network policies for pod-to-pod segmentation
    pod_cidr            = "192.168.0.0/16"
    service_cidr        = "172.16.0.0/16"
    dns_service_ip      = "172.16.0.10"

    load_balancer_sku = "standard"
  }

  # --------------------------------------------------------------------------
  # Entra ID (Azure AD) Integration
  # --------------------------------------------------------------------------
  azure_active_directory_role_based_access_control {
    azure_rbac_enabled = true
    managed            = true
  }

  # --------------------------------------------------------------------------
  # OIDC + Workload Identity — replaces legacy AAD Pod Identity
  # --------------------------------------------------------------------------
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  # --------------------------------------------------------------------------
  # Add-ons
  # --------------------------------------------------------------------------

  # AGIC manages Application Gateway backends from Kubernetes Ingress resources.
  ingress_application_gateway {
    gateway_id = azurerm_application_gateway.main.id
  }

  # Secrets Store CSI Driver mounts Key Vault secrets directly into pods
  # as files or environment variables — no in-cluster secret objects needed.
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    rotation_poll_interval   = "2m"
  }

  # Container Insights sends node/pod metrics and stdout logs to Log Analytics.
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.main.id
  }

  # --------------------------------------------------------------------------
  # Maintenance Window — limit disruptive upgrades to off-peak hours
  # --------------------------------------------------------------------------
  maintenance_window {
    allowed {
      day   = "Sunday"
      hours = [2, 6]
    }
  }

  # --------------------------------------------------------------------------
  # Auto-upgrade — patch-level upgrades are applied automatically
  # --------------------------------------------------------------------------
  automatic_channel_upgrade = "patch"

  lifecycle {
    ignore_changes = [
      # AGIC modifies tags on the managed resource group; ignore to avoid drift
      tags["ingress-appgw-last-applied"],
    ]
  }
}

# --------------------------------------------------------------------------
# Workload Node Pool — runs application pods with autoscaling
# --------------------------------------------------------------------------

resource "azurerm_kubernetes_cluster_node_pool" "workload" {
  name                  = "workload"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vm_size               = var.workload_node_pool_vm_size
  vnet_subnet_id        = azurerm_subnet.aks.id
  os_disk_type          = "Ephemeral"
  os_disk_size_gb       = 128
  max_pods              = 110
  zones                 = ["1", "2", "3"]

  # Cluster Autoscaler adjusts node count based on pending pod requests.
  enable_auto_scaling = true
  min_count           = var.workload_node_pool_min_count
  max_count           = var.workload_node_pool_max_count

  node_labels = {
    "nodepool" = "workload"
  }

  # Taint so only pods that explicitly tolerate this pool get scheduled.
  # Prevents system add-on spillover onto workload nodes.
  node_taints = ["workload=true:NoSchedule"]

  upgrade_settings {
    max_surge = "33%"
  }

  tags = local.tags
}
