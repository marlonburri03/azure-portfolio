"""
Blob Trigger — fires when a new blob is uploaded to the 'raw-uploads'
container, extracts metadata, and writes a record to Cosmos DB.

Design decisions:
- Separate from the event-driven pipeline: this path handles bulk file
  ingestion (CSVs, images, PDFs) independently of the API-driven event flow.
- Metadata extraction only: heavy processing (e.g., parsing large CSVs) should
  be offloaded to a Durable Functions orchestrator to avoid the 10-minute
  consumption-plan timeout.
- Uses the blob path as the Cosmos DB document ID for idempotency.
"""

import hashlib
import logging
import os
from datetime import datetime, timezone

import azure.functions as func
from azure.cosmos import CosmosClient, exceptions
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


def main(blob: func.InputStream) -> None:
    """Entry point for the Blob Storage trigger."""
    blob_name = blob.name or "unknown"
    blob_length = blob.length or 0

    logging.info(
        "BlobTrigger invoked — name=%s size=%d bytes", blob_name, blob_length
    )

    # Compute a content hash for change detection without storing the full blob
    # in Cosmos DB.  Read in chunks to keep memory usage bounded.
    hasher = hashlib.sha256()
    while chunk := blob.read(8192):
        hasher.update(chunk)

    # Use a deterministic ID derived from the blob path so that re-uploads
    # overwrite the previous metadata record (idempotent upsert).
    document_id = hashlib.sha256(blob_name.encode()).hexdigest()

    document = {
        "id": document_id,
        "event_type": "blob.upload",
        "blob_name": blob_name,
        "blob_size_bytes": blob_length,
        "content_sha256": hasher.hexdigest(),
        "processed_at": datetime.now(timezone.utc).isoformat(),
    }

    try:
        container = _get_cosmos_container()
        container.upsert_item(body=document)
        logging.info("Upserted blob metadata — id=%s blob=%s", document_id, blob_name)
    except exceptions.CosmosHttpResponseError:
        logging.exception("Cosmos DB write failed for blob %s", blob_name)
        raise
