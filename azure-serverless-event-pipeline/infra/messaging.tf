# ---------------------------------------------------------------------------
# messaging.tf — Event Grid Topic + Service Bus Namespace & Queue
# ---------------------------------------------------------------------------
# Event Grid provides push-based pub/sub for real-time events from APIM.
# Service Bus adds reliable, ordered message delivery with dead-letter support
# between the Event Grid Handler and the Service Bus Processor functions.
# ---------------------------------------------------------------------------

# ======================== Event Grid ========================================

resource "azurerm_eventgrid_topic" "main" {
  name                = "egt-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  tags                = local.common_tags

  # Use CloudEvents v1.0 schema for interoperability with other systems.
  input_schema = "CloudEventSchemaV1_0"

  # Managed Identity so the topic can deliver events through Private Endpoints.
  identity {
    type = "SystemAssigned"
  }
}

# Subscribe the Event Grid Handler function to the topic.
resource "azurerm_eventgrid_event_subscription" "to_function" {
  name  = "sub-function-handler"
  scope = azurerm_eventgrid_topic.main.id

  azure_function_endpoint {
    function_id = "${azurerm_linux_function_app.main.id}/functions/event_grid_handler"
    # Maximum number of events per batch — 1 keeps processing simple.
    max_events_per_batch = 1
  }

  retry_policy {
    max_delivery_attempts = 5
    event_time_to_live    = 1440 # 24 hours in minutes
  }
}

# ======================== Service Bus =======================================

resource "azurerm_servicebus_namespace" "main" {
  name                          = "sbns-${local.name_prefix}"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  sku                           = var.service_bus_sku
  capacity                      = var.service_bus_sku == "Premium" ? 1 : 0
  public_network_access_enabled = false
  minimum_tls_version           = "1.2"
  tags                          = local.common_tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_servicebus_queue" "events" {
  name         = "events-queue"
  namespace_id = azurerm_servicebus_namespace.main.id

  # Enable duplicate detection so the same Event Grid event ID cannot be
  # enqueued twice within the detection window.
  requires_duplicate_detection         = true
  duplicate_detection_history_time_window = "PT10M"

  # Dead-letter after 3 failed deliveries so poison messages don't block
  # the queue indefinitely.
  max_delivery_count = 3

  # Enable sessions if ordered processing within a partition is needed.
  requires_session = false

  # 14-day default TTL — messages not consumed within this period are discarded.
  default_message_ttl = "P14D"
}

# ---------------------------------------------------------------------------
# Private Endpoint — Service Bus
# ---------------------------------------------------------------------------

resource "azurerm_private_endpoint" "servicebus" {
  name                = "pe-sb-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "psc-sb"
    private_connection_resource_id = azurerm_servicebus_namespace.main.id
    is_manual_connection           = false
    subresource_names              = ["namespace"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.zones["servicebus"].id]
  }
}

# ---------------------------------------------------------------------------
# RBAC — grant Function App's Managed Identity send + receive permissions.
# ---------------------------------------------------------------------------

# "Azure Service Bus Data Sender" — allows the event_grid_handler to enqueue.
resource "azurerm_role_assignment" "function_sb_sender" {
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}

# "Azure Service Bus Data Receiver" — allows the service_bus_processor to dequeue.
resource "azurerm_role_assignment" "function_sb_receiver" {
  scope                = azurerm_servicebus_namespace.main.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = azurerm_linux_function_app.main.identity[0].principal_id
}
