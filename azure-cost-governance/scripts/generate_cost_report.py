#!/usr/bin/env python3
"""Generate a weekly Azure cost report with breakdowns by resource group and service.

Queries the Azure Cost Management API for the specified time window and
produces a human-readable or machine-readable summary.

Authentication uses DefaultAzureCredential — works with Managed Identity
in Azure, OIDC in GitHub Actions, and `az login` locally.
"""

from __future__ import annotations

import argparse
import json
import logging
import sys
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from typing import Any, Sequence

from azure.identity import DefaultAzureCredential
from azure.mgmt.costmanagement import CostManagementClient
from azure.mgmt.costmanagement.models import (
    QueryDefinition,
    QueryDataset,
    QueryAggregation,
    QueryGrouping,
    QueryTimePeriod,
)
from tabulate import tabulate

# ---------------------------------------------------------------------------
# Logging
# ---------------------------------------------------------------------------

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%Y-%m-%dT%H:%M:%S",
)
logger = logging.getLogger(__name__)

# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------


@dataclass
class CostRow:
    """A single row in the cost report."""

    group_name: str  # resource group or service name
    cost: float
    currency: str


@dataclass
class CostReport:
    """Full cost report with two breakdowns."""

    subscription_id: str
    start_date: str
    end_date: str
    by_resource_group: list[CostRow] = field(default_factory=list)
    by_service: list[CostRow] = field(default_factory=list)

    @property
    def total_cost(self) -> float:
        # Use the resource-group breakdown as the authoritative total.
        return sum(r.cost for r in self.by_resource_group)

    @property
    def currency(self) -> str:
        if self.by_resource_group:
            return self.by_resource_group[0].currency
        return "USD"


# ---------------------------------------------------------------------------
# Cost Management queries
# ---------------------------------------------------------------------------


def _query_cost(
    client: CostManagementClient,
    scope: str,
    start: datetime,
    end: datetime,
    group_by_column: str,
) -> list[CostRow]:
    """Run a Cost Management usage query grouped by *group_by_column*.

    The Cost Management API uses a columnar response format rather than
    rows-of-dicts, so we map column indices manually.
    """
    query = QueryDefinition(
        type="Usage",
        timeframe="Custom",
        time_period=QueryTimePeriod(
            from_property=start,
            to_property=end,
        ),
        dataset=QueryDataset(
            granularity="None",
            aggregation={
                "totalCost": QueryAggregation(name="Cost", function="Sum"),
            },
            grouping=[
                QueryGrouping(type="Dimension", name=group_by_column),
            ],
        ),
    )

    # The SDK returns a QueryResult whose `rows` field is a list of lists.
    result = client.query.usage(scope=scope, parameters=query)

    rows: list[CostRow] = []
    if not result.rows:
        logger.warning("No cost data returned for grouping '%s'.", group_by_column)
        return rows

    # Build a column-name → index map so we don't rely on positional order.
    col_index: dict[str, int] = {
        col.name.lower(): i for i, col in enumerate(result.columns)
    }

    cost_idx = col_index.get("cost", 0)
    group_idx = col_index.get(group_by_column.lower(), 1)
    currency_idx = col_index.get("currency", 2)

    for row in result.rows:
        rows.append(
            CostRow(
                group_name=str(row[group_idx]),
                cost=round(float(row[cost_idx]), 2),
                currency=str(row[currency_idx]) if currency_idx < len(row) else "USD",
            )
        )

    # Sort descending by cost so the biggest spenders appear first.
    rows.sort(key=lambda r: r.cost, reverse=True)
    return rows


def generate_report(
    subscription_id: str,
    days: int = 7,
) -> CostReport:
    """Query Cost Management and build a CostReport for the last *days* days."""
    credential = DefaultAzureCredential()
    client = CostManagementClient(credential)

    scope = f"/subscriptions/{subscription_id}"

    end = datetime.now(tz=timezone.utc)
    start = end - timedelta(days=days)

    logger.info(
        "Querying costs for %s from %s to %s …",
        subscription_id,
        start.date(),
        end.date(),
    )

    report = CostReport(
        subscription_id=subscription_id,
        start_date=str(start.date()),
        end_date=str(end.date()),
    )

    try:
        report.by_resource_group = _query_cost(
            client, scope, start, end, "ResourceGroup"
        )
    except Exception:
        logger.exception("Failed to query cost by resource group")

    try:
        report.by_service = _query_cost(
            client, scope, start, end, "ServiceName"
        )
    except Exception:
        logger.exception("Failed to query cost by service name")

    logger.info(
        "Report ready. Total cost: %s %.2f",
        report.currency,
        report.total_cost,
    )
    return report


# ---------------------------------------------------------------------------
# Output formatters
# ---------------------------------------------------------------------------


def _cost_table(rows: list[CostRow], group_label: str) -> str:
    """Render a list of CostRow as a formatted ASCII table."""
    if not rows:
        return "  (no data)\n"
    table_rows = [[r.group_name, f"{r.currency} {r.cost:,.2f}"] for r in rows]
    return tabulate(table_rows, headers=[group_label, "Cost"], floatfmt=",.2f")


def format_table(report: CostReport) -> str:
    """Render the full report as human-readable text."""
    lines = [
        f"Azure Cost Report  ({report.start_date} → {report.end_date})",
        f"Subscription: {report.subscription_id}",
        f"Total Cost:   {report.currency} {report.total_cost:,.2f}",
        "",
        "── By Resource Group ──",
        _cost_table(report.by_resource_group, "Resource Group"),
        "",
        "── By Service ──",
        _cost_table(report.by_service, "Service"),
    ]
    return "\n".join(lines)


def format_json(report: CostReport) -> str:
    """Serialize the report as JSON for downstream automation."""
    payload: dict[str, Any] = {
        "subscription_id": report.subscription_id,
        "start_date": report.start_date,
        "end_date": report.end_date,
        "total_cost": report.total_cost,
        "currency": report.currency,
        "by_resource_group": [
            {"name": r.group_name, "cost": r.cost, "currency": r.currency}
            for r in report.by_resource_group
        ],
        "by_service": [
            {"name": r.group_name, "cost": r.cost, "currency": r.currency}
            for r in report.by_service
        ],
    }
    return json.dumps(payload, indent=2)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate a weekly Azure cost summary.",
    )
    parser.add_argument(
        "--subscription-id",
        required=True,
        help="Azure subscription ID to query.",
    )
    parser.add_argument(
        "--days",
        type=int,
        default=7,
        help="Look-back window in days (default: 7).",
    )
    parser.add_argument(
        "--output",
        choices=["table", "json"],
        default="table",
        help="Output format (default: table).",
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> None:
    args = parse_args(argv)
    report = generate_report(args.subscription_id, args.days)

    if args.output == "json":
        print(format_json(report))
    else:
        print(format_table(report))


if __name__ == "__main__":
    main()
