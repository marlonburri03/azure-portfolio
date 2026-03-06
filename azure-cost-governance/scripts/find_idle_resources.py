#!/usr/bin/env python3
"""Detect idle Azure resources that incur unnecessary cost.

Scans a subscription for:
  - Deallocated VMs        (still billed for OS/data disks)
  - Unattached managed disks
  - Orphaned NICs          (not bound to any VM)
  - Orphaned public IPs    (not associated with any NIC or LB)

Authentication uses DefaultAzureCredential so the same script works
locally (az login), in CI (OIDC / service principal), and inside
Azure (Managed Identity) without code changes.
"""

from __future__ import annotations

import argparse
import json
import logging
import sys
from dataclasses import asdict, dataclass, field
from typing import Sequence

from azure.identity import DefaultAzureCredential
from azure.mgmt.compute import ComputeManagementClient
from azure.mgmt.network import NetworkManagementClient
from tabulate import tabulate

# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

@dataclass
class IdleResource:
    """Single idle resource detected during a scan."""

    resource_type: str
    name: str
    resource_group: str
    reason: str
    resource_id: str


@dataclass
class ScanResult:
    """Aggregated results of a full subscription scan."""

    subscription_id: str
    idle_resources: list[IdleResource] = field(default_factory=list)

    @property
    def total(self) -> int:
        return len(self.idle_resources)


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
# Scanners — each function yields IdleResource instances
# ---------------------------------------------------------------------------


def scan_deallocated_vms(
    compute_client: ComputeManagementClient,
) -> list[IdleResource]:
    """Find VMs whose power state is 'deallocated'.

    Deallocated VMs still incur charges for any Premium/Ultra disks
    attached to them and continue to reserve their IP configuration.
    """
    idle: list[IdleResource] = []
    for vm in compute_client.virtual_machines.list_all():
        # Instance view is required to read the power state — the
        # default list operation does not include it.
        rg = vm.id.split("/")[4]  # /subscriptions/.../resourceGroups/<RG>/...
        instance_view = compute_client.virtual_machines.instance_view(rg, vm.name)
        power_states = [
            s.code
            for s in (instance_view.statuses or [])
            if s.code.startswith("PowerState/")
        ]
        if "PowerState/deallocated" in power_states:
            idle.append(
                IdleResource(
                    resource_type="VirtualMachine",
                    name=vm.name,
                    resource_group=rg,
                    reason="VM is deallocated — still incurs disk charges",
                    resource_id=vm.id,
                )
            )
            logger.info("Deallocated VM: %s in %s", vm.name, rg)
    return idle


def scan_unattached_disks(
    compute_client: ComputeManagementClient,
) -> list[IdleResource]:
    """Find managed disks whose disk_state is 'Unattached'.

    Unattached disks are fully billable. They are often left behind
    after a VM is deleted because Azure does not auto-delete data disks.
    """
    idle: list[IdleResource] = []
    for disk in compute_client.disks.list():
        if disk.disk_state == "Unattached":
            rg = disk.id.split("/")[4]
            idle.append(
                IdleResource(
                    resource_type="ManagedDisk",
                    name=disk.name,
                    resource_group=rg,
                    reason=f"Disk is unattached — {disk.disk_size_gb} GB still billed",
                    resource_id=disk.id,
                )
            )
            logger.info("Unattached disk: %s (%s GB)", disk.name, disk.disk_size_gb)
    return idle


def scan_orphaned_nics(
    network_client: NetworkManagementClient,
) -> list[IdleResource]:
    """Find NICs not attached to any virtual machine.

    Orphaned NICs are free, but they clutter the environment and often
    hold reserved private IPs that block CIDR reuse.
    """
    idle: list[IdleResource] = []
    for nic in network_client.network_interfaces.list_all():
        # A NIC is orphaned when virtual_machine is None.
        if nic.virtual_machine is None:
            rg = nic.id.split("/")[4]
            idle.append(
                IdleResource(
                    resource_type="NetworkInterface",
                    name=nic.name,
                    resource_group=rg,
                    reason="NIC is not attached to any VM",
                    resource_id=nic.id,
                )
            )
            logger.info("Orphaned NIC: %s", nic.name)
    return idle


def scan_orphaned_public_ips(
    network_client: NetworkManagementClient,
) -> list[IdleResource]:
    """Find public IPs not associated with any NIC or load balancer.

    Standard-SKU public IPs are billed even when idle. Cleaning them
    up directly reduces cost.
    """
    idle: list[IdleResource] = []
    for ip in network_client.public_ip_addresses.list_all():
        # ip_configuration is set when the IP is bound to a NIC or LB.
        if ip.ip_configuration is None:
            rg = ip.id.split("/")[4]
            idle.append(
                IdleResource(
                    resource_type="PublicIPAddress",
                    name=ip.name,
                    resource_group=rg,
                    reason=f"Public IP ({ip.sku.name} SKU) is unassociated — billed if Standard",
                    resource_id=ip.id,
                )
            )
            logger.info("Orphaned public IP: %s", ip.name)
    return idle


# ---------------------------------------------------------------------------
# Orchestrator
# ---------------------------------------------------------------------------


def run_scan(subscription_id: str) -> ScanResult:
    """Execute all idle-resource scanners and return consolidated results."""
    # DefaultAzureCredential tries Managed Identity → az CLI → env vars,
    # so the same code works in every execution context.
    credential = DefaultAzureCredential()

    compute_client = ComputeManagementClient(credential, subscription_id)
    network_client = NetworkManagementClient(credential, subscription_id)

    result = ScanResult(subscription_id=subscription_id)

    scanners = [
        ("Deallocated VMs", lambda: scan_deallocated_vms(compute_client)),
        ("Unattached Disks", lambda: scan_unattached_disks(compute_client)),
        ("Orphaned NICs", lambda: scan_orphaned_nics(network_client)),
        ("Orphaned Public IPs", lambda: scan_orphaned_public_ips(network_client)),
    ]

    for label, scanner in scanners:
        logger.info("Scanning: %s …", label)
        try:
            result.idle_resources.extend(scanner())
        except Exception:
            # Log the error but continue with remaining scanners so a
            # single RBAC gap doesn't abort the entire report.
            logger.exception("Scanner '%s' failed — skipping", label)

    logger.info("Scan complete. %d idle resource(s) found.", result.total)
    return result


# ---------------------------------------------------------------------------
# Output formatters
# ---------------------------------------------------------------------------


def format_table(resources: Sequence[IdleResource]) -> str:
    """Render idle resources as an ASCII table for terminal output."""
    if not resources:
        return "✅ No idle resources found."
    rows = [
        [r.resource_type, r.resource_group, r.name, r.reason] for r in resources
    ]
    return tabulate(rows, headers=["Type", "Resource Group", "Name", "Reason"])


def format_json(result: ScanResult) -> str:
    """Serialize the full scan result as JSON for downstream automation."""
    return json.dumps(
        {
            "subscription_id": result.subscription_id,
            "total": result.total,
            "idle_resources": [asdict(r) for r in result.idle_resources],
        },
        indent=2,
    )


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Detect idle Azure resources that waste money.",
    )
    parser.add_argument(
        "--subscription-id",
        required=True,
        help="Azure subscription ID to scan.",
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
    result = run_scan(args.subscription_id)

    if args.output == "json":
        print(format_json(result))
    else:
        print(format_table(result.idle_resources))

    # Exit non-zero when idle resources are found so CI pipelines can
    # gate on the result.
    if result.total > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
