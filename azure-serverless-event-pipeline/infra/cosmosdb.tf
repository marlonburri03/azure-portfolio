# ---------------------------------------------------------------------------
# cosmosdb.tf — Cosmos DB account, database, and container
# ---------------------------------------------------------------------------
# Cosmos DB stores processed events.  Key design choices:
# - Partition key: /event_type — co-locates related events for efficient
#   single-partition queries while distributing writes.
# - Autoscale throughput: scales between 10 % and max RU/s automatically.
# - Analytical store: enabled for downstream analytics without impacting
#   transactional workloads (HTAP pattern).
# ---------------------------------------------------------------------------

resource "azurerm_cosmosdb_account" "main" {
  name                          = "cosmos-${local.name_prefix}"
  location                      = azurerm_resource_group.main.location
  resource_group_name           = azurerm_resource_group.main.name
  offer_type                    = "Standard"
  kind                          = "GlobalDocumentDB" # Core (SQL) API
  public_network_access_enabled = false
  tags                          = local.common_tags

  # Enable the analytical store for Azure Synapse Link integration.
  analytical_storage_enabled = true

  consistency_policy {
    # Session consistency gives read-your-writes semantics within a session
    # while keeping costs lower than Strong consistency.
    consistency_level = "Session"
  }

  geo_location {
    location          = azurerm_resource_group.main.location
    failover_priority = 0
  }

  # Restrict access to the VNet — public queries are blocked.
  is_virtual_network_filter_enabled = true
}

# ---------------------------------------------------------------------------
# Database & Container
# ---------------------------------------------------------------------------

resource "azurerm_cosmosdb_sql_database" "events" {
  name                = "events-db"
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
}

resource "azurerm_cosmosdb_sql_container" "processed_events" {
  name                = "processed-events"
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
  database_name       = azurerm_cosmosdb_sql_database.events.name
  partition_key_paths = ["/event_type"]

  # Autoscale: Cosmos DB adjusts throughput automatically between 10% and max.
  autoscale_settings {
    max_throughput = var.cosmos_db_throughput
  }

  # Default TTL of 90 days (in seconds).  Individual documents can override.
  default_ttl = 7776000

  indexing_policy {
    indexing_mode = "consistent"

    # Only index fields we query on — reduces RU cost for writes.
    included_path {
      path = "/event_type/?"
    }
    included_path {
      path = "/processed_at/?"
    }
    excluded_path {
      path = "/*"
    }
  }
}

# ---------------------------------------------------------------------------
# Private Endpoint
# ---------------------------------------------------------------------------

resource "azurerm_private_endpoint" "cosmos" {
  name                = "pe-cosmos-${local.name_prefix}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.common_tags

  private_service_connection {
    name                           = "psc-cosmos"
    private_connection_resource_id = azurerm_cosmosdb_account.main.id
    is_manual_connection           = false
    subresource_names              = ["Sql"]
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.zones["cosmos"].id]
  }
}

# ---------------------------------------------------------------------------
# RBAC — grant the Function App's identity read/write access to Cosmos DB.
# "Cosmos DB Built-in Data Contributor" is the data-plane RBAC role.
# ---------------------------------------------------------------------------

resource "azurerm_cosmosdb_sql_role_assignment" "function_data_contributor" {
  resource_group_name = azurerm_resource_group.main.name
  account_name        = azurerm_cosmosdb_account.main.name
  # Built-in "Cosmos DB Built-in Data Contributor" role definition ID.
  role_definition_id = "${azurerm_cosmosdb_account.main.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id       = azurerm_linux_function_app.main.identity[0].principal_id
  scope              = azurerm_cosmosdb_account.main.id
}
