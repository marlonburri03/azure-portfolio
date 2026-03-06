"""
Event Grid Handler — receives events published by API Management and routes
them to a Service Bus queue for reliable downstream processing.

Design decisions:
- Idempotent: uses the Event Grid event ID as the Service Bus message ID so
  duplicate deliveries (at-least-once) are deduplicated by Service Bus.
- Structured logging: emits correlation IDs for distributed tracing through
  Application Insights.
- No secrets in code: connection strings are resolved at runtime via Key Vault
  references configured in Application Settings.
"""

import json
import logging
import os
from datetime import datetime, timezone

import azure.functions as func
from azure.identity import DefaultAzureCredential
from azure.servicebus import ServiceBusClient, ServiceBusMessage

# Reuse the client across invocations to benefit from connection pooling.
_sb_client = None


def _get_service_bus_client() -> ServiceBusClient:
    """Lazily initialise the Service Bus client with Managed Identity."""
    global _sb_client
    if _sb_client is None:
        namespace = os.environ["SERVICE_BUS_NAMESPACE"]
        # DefaultAzureCredential picks up the Function App's system-assigned
        # Managed Identity in Azure and the developer's az-cli credential locally.
        credential = DefaultAzureCredential()
        _sb_client = ServiceBusClient(
            fully_qualified_namespace=f"{namespace}.servicebus.windows.net",
            credential=credential,
        )
    return _sb_client


def main(event: func.EventGridEvent) -> None:
    """Entry point for the Event Grid trigger."""
    logging.info(
        "EventGridHandler invoked — id=%s subject=%s type=%s",
        event.id,
        event.subject,
        event.event_type,
    )

    enriched_payload = {
        "source_event_id": event.id,
        "event_type": event.event_type,
        "subject": event.subject,
        "data": event.get_json(),
        "received_at": datetime.now(timezone.utc).isoformat(),
    }

    queue_name = os.environ.get("SERVICE_BUS_QUEUE_NAME", "events-queue")

    try:
        client = _get_service_bus_client()
        with client.get_queue_sender(queue_name) as sender:
            message = ServiceBusMessage(
                body=json.dumps(enriched_payload),
                # Using the Event Grid event ID as the message ID enables
                # duplicate detection on the Service Bus queue.
                message_id=event.id,
                content_type="application/json",
                subject=event.event_type,
            )
            sender.send_messages(message)

        logging.info(
            "Enqueued message to '%s' — message_id=%s", queue_name, event.id
        )
    except Exception:
        logging.exception("Failed to enqueue message for event %s", event.id)
        # Re-raise so the Functions runtime marks the invocation as failed and
        # Event Grid retries delivery according to its retry policy.
        raise
