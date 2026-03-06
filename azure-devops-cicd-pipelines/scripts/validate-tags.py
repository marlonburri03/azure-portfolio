#!/usr/bin/env python3
"""
Validate Azure Resource Tags
=============================================================================
Ensures all Azure resources in a Terraform plan or state file carry the
required tags defined by organizational policy. Missing tags are the #1
cause of cost allocation failures and audit findings.

Usage:
    python validate-tags.py --plan tfplan.json
    python validate-tags.py --state terraform.tfstate

Exit codes:
    0 — All resources have required tags
    1 — One or more resources are missing required tags
    2 — Input/argument error
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Any

# Tags required by organizational policy — update to match your governance rules
REQUIRED_TAGS = {
    "Environment",   # dev, staging, prod — drives cost allocation
    "Owner",         # Team or individual responsible for the resource
    "CostCenter",    # Finance code for chargeback/showback
    "Project",       # Project or workload identifier
    "ManagedBy",     # "terraform", "bicep", "manual" — tracks IaC coverage
}

# Azure resource types that don't support tags (skip validation for these)
TAG_EXEMPT_TYPES = {
    "azurerm_resource_group_policy_assignment",
    "azurerm_role_assignment",
    "azurerm_role_definition",
    "azurerm_management_lock",
    "azurerm_subnet",              # Subnets inherit from VNet
    "azurerm_subnet_route_table_association",
    "azurerm_subnet_network_security_group_association",
}


def load_plan(plan_path: Path) -> dict[str, Any]:
    """Load a terraform plan JSON file (output of `terraform show -json tfplan`)."""
    try:
        with open(plan_path) as f:
            return json.load(f)
    except (json.JSONDecodeError, FileNotFoundError) as e:
        print(f"❌ Error reading plan file: {e}", file=sys.stderr)
        sys.exit(2)


def extract_resources_from_plan(plan: dict[str, Any]) -> list[dict[str, Any]]:
    """Extract planned resource changes that create or update resources."""
    resources = []
    for change in plan.get("resource_changes", []):
        actions = change.get("change", {}).get("actions", [])
        # Only validate resources being created or updated (not destroyed)
        if any(action in actions for action in ("create", "update")):
            after = change.get("change", {}).get("after", {})
            resources.append({
                "address": change.get("address", "unknown"),
                "type": change.get("type", "unknown"),
                "tags": after.get("tags") or {},
            })
    return resources


def extract_resources_from_state(state: dict[str, Any]) -> list[dict[str, Any]]:
    """Extract resources from a terraform state file."""
    resources = []
    for res in state.get("resources", []):
        for instance in res.get("instances", []):
            attrs = instance.get("attributes", {})
            resources.append({
                "address": f"{res.get('type', 'unknown')}.{res.get('name', 'unknown')}",
                "type": res.get("type", "unknown"),
                "tags": attrs.get("tags") or {},
            })
    return resources


def validate_tags(resources: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Check each resource for required tags. Returns list of violations."""
    violations = []
    for resource in resources:
        # Skip resources that don't support tags
        if resource["type"] in TAG_EXEMPT_TYPES:
            continue

        resource_tags = set(resource.get("tags", {}).keys())
        missing = REQUIRED_TAGS - resource_tags

        if missing:
            violations.append({
                "address": resource["address"],
                "type": resource["type"],
                "missing_tags": sorted(missing),
            })

    return violations


def print_results(violations: list[dict[str, Any]], total: int) -> None:
    """Print a formatted report of tag validation results."""
    if not violations:
        print(f"✅ All {total} resources have required tags: {', '.join(sorted(REQUIRED_TAGS))}")
        return

    print(f"❌ {len(violations)} of {total} resources are missing required tags:\n")
    for v in violations:
        print(f"  Resource: {v['address']}")
        print(f"  Type:     {v['type']}")
        print(f"  Missing:  {', '.join(v['missing_tags'])}")
        print()

    print("Required tags:", ", ".join(sorted(REQUIRED_TAGS)))


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Validate Azure resource tags in Terraform plan or state files"
    )
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--plan", type=Path, help="Path to terraform plan JSON file")
    group.add_argument("--state", type=Path, help="Path to terraform state file")
    args = parser.parse_args()

    if args.plan:
        data = load_plan(args.plan)
        resources = extract_resources_from_plan(data)
    else:
        data = load_plan(args.state)
        resources = extract_resources_from_state(data)

    if not resources:
        print("⚠️  No resources found to validate")
        sys.exit(0)

    violations = validate_tags(resources)
    print_results(violations, len(resources))

    sys.exit(1 if violations else 0)


if __name__ == "__main__":
    main()
