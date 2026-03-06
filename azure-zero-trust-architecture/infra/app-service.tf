# =============================================================================
# App Service — application compute with VNet integration
#
# Zero Trust principle: Least-privilege access. The App Service uses a
# system-assigned Managed Identity to authenticate to Key Vault and Storage —
# no credentials stored anywhere. VNet integration ensures all outbound
# traffic stays on the private network.
# =============================================================================

resource "azurerm_service_plan" "main" {
  name                = "plan-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  os_type             = "Linux"
  # Premium tier is required for VNet integration and Private Endpoint support
  sku_name            = var.app_service_sku
  tags                = local.common_tags
}

resource "azurerm_linux_web_app" "main" {
  name                = "app-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  service_plan_id     = azurerm_service_plan.main.id
  tags                = local.common_tags

  # VNet integration routes all outbound App Service traffic through the
  # spoke VNet, ensuring it hits the route table → Azure Firewall path.
  virtual_network_subnet_id = azurerm_subnet.app_integration.id

  # System-assigned Managed Identity — the app authenticates to Azure services
  # as itself, no client secrets or connection strings required.
  identity {
    type = "SystemAssigned"
  }

  site_config {
    # Require TLS 1.2 minimum — older versions have known vulnerabilities
    minimum_tls_version = "1.2"

    # Only allow traffic from the VNet (via Firewall DNAT or Private Endpoint).
    # Combined with the NSG rules, this creates defense-in-depth.
    ip_restriction_default_action = "Deny"

    ip_restriction {
      name                      = "allow-firewall-subnet"
      priority                  = 100
      action                    = "Allow"
      virtual_network_subnet_id = azurerm_subnet.firewall.id
    }

    application_stack {
      dotnet_version = "8.0"
    }

    # Force all outbound calls through the VNet instead of the shared
    # multi-tenant outbound IPs — critical for firewall routing to work.
    vnet_route_all_enabled = true
  }

  app_settings = {
    # Reference Key Vault secrets via App Service's native integration —
    # the runtime fetches secrets at startup using the Managed Identity.
    "KeyVaultUri" = azurerm_key_vault.main.vault_uri

    # Instrumentation key for Application Insights (via Log Analytics)
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.main.connection_string

    # Enforce HTTPS-only to prevent accidental cleartext traffic
    "WEBSITE_HTTPSONLY" = "true"
  }

  # Prevent the app from being accessible over the public internet.
  # Only Private Endpoint and VNet-integrated traffic can reach it.
  public_network_access_enabled = false

  https_only = true

  logs {
    http_logs {
      file_system {
        retention_in_days = 30
        retention_in_mb   = 100
      }
    }
    application_logs {
      file_system_level = "Warning"
    }
  }
}

# -----------------------------------------------------------------------------
# Application Insights — connected to the Sentinel Log Analytics workspace
# so application telemetry is available for security correlation.
# -----------------------------------------------------------------------------

resource "azurerm_application_insights" "main" {
  name                = "appi-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  workspace_id        = azurerm_log_analytics_workspace.sentinel.id
  application_type    = "web"
  tags                = local.common_tags
}

# -----------------------------------------------------------------------------
# Diagnostic Settings — App Service audit and HTTP logs to Log Analytics
# -----------------------------------------------------------------------------

resource "azurerm_monitor_diagnostic_setting" "app_service" {
  name                       = "diag-app-${local.name_prefix}"
  target_resource_id         = azurerm_linux_web_app.main.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.sentinel.id

  enabled_log {
    category = "AppServiceHTTPLogs"
  }

  enabled_log {
    category = "AppServiceAuditLogs"
  }

  enabled_log {
    category = "AppServicePlatformLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = true
  }
}
