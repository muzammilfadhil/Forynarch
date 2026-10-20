#!/usr/bin/env python3
"""Pure optional-package planner for authoring/builder tooling. Never installs."""

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

NAME = re.compile(r"[a-z0-9][a-z0-9@._+\-]*\Z")
POLICY = {
    "developer_groups_default": False,
    "user_must_opt_in": True,
    "network_required_for_unbundled_packages": True,
    "use_official_signed_arch_packages": True,
}


class PlanError(ValueError):
    pass


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise PlanError(f"duplicate object key: {key}")
        result[key] = value
    return result


def load_catalog(path):
    # The canonical .yaml file deliberately uses JSON serialization: valid YAML
    # 1.2, with no third-party parser dependency in the authoring tools.
    try:
        catalog = json.loads(Path(path).read_text(encoding="utf-8"),
                             object_pairs_hook=unique_object)
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        raise PlanError(f"cannot read JSON-serialized catalog: {error}") from error
    return validate_catalog(catalog)


def validate_catalog(catalog):
    if not isinstance(catalog, dict) or set(catalog) != {
        "schema_version", "kind", "policy", "groups"
    }:
        raise PlanError("unexpected catalog fields")
    if type(catalog["schema_version"]) is not int or catalog["schema_version"] != 1:
        raise PlanError("unsupported schema version")
    if catalog["kind"] != "optional-package-catalog":
        raise PlanError("unexpected catalog kind")
    policy = catalog["policy"]
    if not isinstance(policy, dict) or set(policy) != set(POLICY):
        raise PlanError("unexpected policy fields")
    if any(type(policy[key]) is not bool or policy[key] is not value
           for key, value in POLICY.items()):
        raise PlanError("unsafe optional-package policy")
    groups = catalog["groups"]
    if not isinstance(groups, list) or not groups:
        raise PlanError("groups must be a nonempty list")
    seen = set()
    fields = {"id", "category", "label", "description", "default", "packages"}
    for group in groups:
        if not isinstance(group, dict) or set(group) not in (fields, fields | {"flatpaks"}):
            raise PlanError("unexpected group fields")
        group_id = group["id"]
        if "flatpaks" in group:
            reviewed = {"google-chrome": ["com.google.Chrome"], "zen": ["app.zen_browser.zen"], "zoom": ["us.zoom.Zoom"], "vscode": ["com.visualstudio.code"]}
            if reviewed.get(group_id) != group["flatpaks"] or group.get("packages") != ["flatpak"]:
                raise PlanError("unreviewed external application mapping")
        if not isinstance(group_id, str) or not NAME.fullmatch(group_id):
            raise PlanError("invalid group ID")
        if group_id in seen:
            raise PlanError(f"duplicate group ID: {group_id}")
        seen.add(group_id)
        if group["default"] is not False:
            raise PlanError(f"group must default to false: {group_id}")
        if group["category"] not in ("development", "daily"):
            raise PlanError(f"unsupported category: {group_id}")
        for field in ("label", "description"):
            if not isinstance(group[field], str) or not group[field].strip():
                raise PlanError(f"missing {field}: {group_id}")
        packages = group["packages"]
        if not isinstance(packages, list) or not packages:
            raise PlanError(f"empty packages: {group_id}")
        if any(not isinstance(package, str) or not NAME.fullmatch(package)
               for package in packages):
            raise PlanError(f"invalid package name: {group_id}")
        if len(set(packages)) != len(packages):
            raise PlanError(f"duplicate package in group: {group_id}")
        if group_id == "nodejs-npm" and set(packages) != {"nodejs", "npm"}:
            raise PlanError("nodejs-npm must contain both nodejs and npm only")
    if "nodejs-npm" not in seen:
        raise PlanError("required nodejs-npm selection missing")
    return catalog


def create_plan(catalog, selected=(), offline=False):
    validate_catalog(catalog)
    if type(offline) is not bool:
        raise PlanError("offline must be boolean")
    if not isinstance(selected, (list, tuple)) or any(
        not isinstance(item, str) for item in selected
    ):
        raise PlanError("selection must be a list of group IDs")
    groups = {group["id"]: group for group in catalog["groups"]}
    selected_ids = sorted(set(selected))
    unknown = sorted(set(selected_ids) - set(groups))
    if unknown:
        raise PlanError("unknown selection: " + ", ".join(unknown))
    # No offline optional bundle has been built/verified yet. Fail closed.
    if offline and selected_ids:
        raise PlanError("optional packages unavailable offline; no verified bundle")
    packages = sorted({package for group_id in selected_ids
                       for package in groups[group_id]["packages"]})
    serialized = json.dumps(catalog, sort_keys=True, separators=(",", ":"))
    return {
        "schema_version": 1,
        "kind": "optional-package-plan-preview",
        "catalog_sha256": hashlib.sha256(serialized.encode()).hexdigest(),
        "selected_group_ids": selected_ids,
        "explicit_optional_packages": packages,
        "selected_flatpaks": sorted({app for group in catalog["groups"] if group["id"] in selected_ids for app in group.get("flatpaks", [])}),
        "offline": offline,
        "dependency_resolution": "pending-arch-validation",
        "repository_snapshot": None,
        "additional_dependencies": None,
        "download_bytes": None,
        "execution_allowed": False,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--catalog", type=Path,
                        default=Path(__file__).resolve().parents[1] /
                        "packages/optional-catalog.yaml")
    parser.add_argument("--select", action="append", default=[], metavar="GROUP_ID")
    parser.add_argument("--offline", action="store_true")
    args = parser.parse_args(argv)
    try:
        plan = create_plan(load_catalog(args.catalog), args.select, args.offline)
    except PlanError as error:
        print(f"Error: {error}", file=sys.stderr)
        return 2
    print(json.dumps(plan, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
