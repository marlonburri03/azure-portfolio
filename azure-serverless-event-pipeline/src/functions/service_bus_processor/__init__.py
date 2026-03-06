"""
Service Bus Processor — consumes messages from the events queue, transforms
them, and writes the result to Cosmos DB with an idempotent upsert.

Design decisions:
- Idempotent writes: uses the source event ID as the Cosmos DB document `id`
  so reprocessed messages overwrite rather than duplicate.
- Partition key: uses `event_type` to co-locate related events for efficient
  queries while distributing writes across logical partitions.
- Dead-letter handling: messages that fail repeatedly are moved to the
  dead-letter sub-queue by Service Bus (configured in messaging.tf).
"""

import json
import logging
import os
from datetime import datetime, timezone

import azure.functions as func
from azure.cosmos import CosmosClient, PartitionKey, exceptions
from azure.identity import DefaultAzureCredential

_cosmos_client = None
_container = None


def _get_cosmos_container():
    """Lazily initialise the Cosmos DB container client with Managed Identity."""
    global _cosmos_client, _container
    if _container is None:
        endpoint = os.environ["COSMOS_DB_ENDPOINT"]
        database_name = os.environ.get("COSMOS_DB_DATABASE", "events-db")
        container_name = os.environ.get("COSMOS_DB_CONTAINER", "processed-events")

        credential = DefaultAzureCredential()
        _cosmos_client = CosmosClient(url=endpoint, credential=credential)
        database = _cosmos_client.get_database_client(database_name)
        _container = database.get_container_client(container_name)
    return _container


def main(message: func.ServiceBusMessage) -> None:
    """Entry point for the Service Bus queue trigger."""
    message_id = message.message_id
    logging.info("ServiceBusProcessor invoked — message_id=%s", message_id)

    body = message.get_body().decode("utf-8")
    payload = json.loads(body)

    # Build the Cosmos DB document.  The `id` field is set to the original
    # Event Grid event ID so that retries produce upserts, not duplicates.
    document = {
        "id": payload["source_event_id"],
        "event_type": payload["event_type"],
        "subject": payload["subject"],
        "data": payload["data"],
        "processed_at": datetime.now(timezone.utc).isoformat(),
        "source_queue_message_id": message_id,
    }

    try:
        container = _get_cosmos_container()
        # upsert_item is idempotent — safe for at-least-once delivery.
        container.upsert_item(body=document)
        logging.info(
            "Upserted document id=%s partition_key=%s",
            document["id"],
            document["event_type"],
        )
    except exceptions.CosmosHttpResponseError:
        logging.exception(
            "Cosmos DB write failed for document id=%s", document["id"]
        )
        # Re-raise to let Service Bus retry and eventually dead-letter.
        raise
