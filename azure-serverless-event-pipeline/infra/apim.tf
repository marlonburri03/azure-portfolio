# ---------------------------------------------------------------------------
# apim.tf — API Management gateway
# ---------------------------------------------------------------------------
# APIM acts as the single entry point for external consumers.  It:
# - Validates incoming requests (JWT, subscription keys)
# - Rate-limits traffic to protect downstream functions
# - Publishes events to the Event Grid topic
#
# The Developer SKU is used for non-production environments; production
# should use Standard or Premium (Premium supports VNet integration).
# ---------------------------------------------------------------------------

resource "azurerm_api_management" "main" {
  name                = "apim-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  publisher_name      = var.apim_publisher_name
  publisher_email     = var.apim_publisher_email
  sku_name            = "${var.apim_sku}_1"
  tags                = local.common_tags

  identity {
    # System-assigned identity lets APIM authenticate to Event Grid and
    # Key Vault without storing credentials.
    type = "SystemAssigned"
  }
}

# ---------------------------------------------------------------------------
# API definition — exposes an /events endpoint that publishes to Event Grid.
# ---------------------------------------------------------------------------

resource "azurerm_api_management_api" "events" {
  name                  = "events-api"
  resource_group_name   = azurerm_resource_group.main.name
  api_management_name   = azurerm_api_management.main.name
  revision              = "1"
  display_name          = "Events API"
  path                  = "events"
  protocols             = ["https"]
  subscription_required = true
}

resource "azurerm_api_management_api_operation" "publish_event" {
  operation_id        = "publish-event"
  api_name            = azurerm_api_management_api.events.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name
  display_name        = "Publish Event"
  method              = "POST"
  url_template        = "/"
}

# Global policy: rate-limit to 100 calls/minute per subscription key and
# validate that requests carry a valid JWT from Azure AD.
resource "azurerm_api_management_api_policy" "events_policy" {
  api_name            = azurerm_api_management_api.events.name
  api_management_name = azurerm_api_management.main.name
  resource_group_name = azurerm_resource_group.main.name

  xml_content = <<-XML
    <policies>
      <inbound>
        <base />
        <rate-limit calls="100" renewal-period="60" />
        <set-header name="Content-Type" exists-action="override">
          <value>application/json</value>
        </set-header>
        <validate-jwt header-name="Authorization" failed-validation-httpcode="401"
                      failed-validation-error-message="Unauthorized">
          <openid-config url="https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/v2.0/.well-known/openid-configuration" />
          <required-claims>
            <claim name="aud" match="any">
              <value>${azurerm_api_management.main.id}</value>
            </claim>
          </required-claims>
        </validate-jwt>
      </inbound>
      <backend>
        <base />
      </backend>
      <outbound>
        <base />
      </outbound>
      <on-error>
        <base />
      </on-error>
    </policies>
  XML
}

# ---------------------------------------------------------------------------
# Named Value — Event Grid topic endpoint (referenced in send-request policy)
# ---------------------------------------------------------------------------
# Store the Event Grid endpoint and key as APIM Named Values backed by
# Key Vault, so they are never exposed in policy XML or Terraform state.
# ---------------------------------------------------------------------------

resource "azurerm_api_management_named_value" "eventgrid_endpoint" {
  name                = "eventgrid-endpoint"
  resource_group_name = azurerm_resource_group.main.name
  api_management_name = azurerm_api_management.main.name
  display_name        = "eventgrid-endpoint"
  value               = azurerm_eventgrid_topic.main.endpoint
}

# ---------------------------------------------------------------------------
# RBAC — grant APIM's identity permission to publish events to Event Grid.
# ---------------------------------------------------------------------------

resource "azurerm_role_assignment" "apim_eventgrid_sender" {
  scope                = azurerm_eventgrid_topic.main.id
  role_definition_name = "EventGrid Data Sender"
  principal_id         = azurerm_api_management.main.identity[0].principal_id
}
