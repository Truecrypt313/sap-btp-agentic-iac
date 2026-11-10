#!/usr/bin/env python3
"""Mandatory external data source: read HCP prior state, compare SAP inventory.

No state/output dump, local state file, input ID, import, or write API exists.
Only the fixed address in the authenticated run's own workspace proves ownership.
Python standard library only; runs automatically before directory plan actions.
"""
import json
import os
import re
import sys
from urllib.error import HTTPError, URLError
from urllib.parse import urlsplit
from urllib.request import Request, HTTPRedirectHandler, build_opener

ORGANIZATION = "sap-ai-landing-zone"
API = "https://app.terraform.io/api/v2"
ADDRESS = 'module.directory.btp_directory.this["project"]'
UUID = re.compile(r"[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}")
MAX_BYTES = 32 * 1024 * 1024


class PreflightError(ValueError):
    """Safe diagnostic without response bodies, tokens or signed download URLs."""


def require(condition, message):
    if not condition:
        raise PreflightError(message)


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise PreflightError("Unexpected redirect; refusing to forward credentials or state URLs.")


def read_json(url, token=None):
    parsed = urlsplit(url)
    require(parsed.scheme == "https" and parsed.hostname and not parsed.username and not parsed.password,
            "State/API URL must use HTTPS without embedded credentials.")
    headers = {"Accept": "application/vnd.api+json"}
    if token:
        require(url.startswith(API + "/"), "Refusing authentication outside the fixed HCP API.")
        headers["Authorization"] = "Bearer " + token
    try:
        with build_opener(NoRedirect()).open(Request(url, headers=headers, method="GET"), timeout=30) as response:
            content = response.read(MAX_BYTES + 1)
        require(len(content) <= MAX_BYTES, "HCP response exceeds the supported size.")
        return json.loads(content)
    except HTTPError as error:
        # A 404 may mean missing permission; it must NEVER mean an empty state.
        raise PreflightError(f"HCP read failed (HTTP {error.code}); no ownership proof available.") from None
    except (URLError, TimeoutError, OSError, UnicodeError, json.JSONDecodeError):
        raise PreflightError("HCP response unavailable or invalid; no ownership proof available.") from None


def managed_directory_id(state):
    """Read the actual managed instance, never project_contract or another output."""
    if state is None:
        return ""
    require(state["version"] == 4 and UUID.fullmatch(state["lineage"])
            and type(state["serial"]) is int and state["serial"] >= 0
            and isinstance(state["resources"], list), "Unsupported or incomplete Terraform state.")
    matches = []
    for resource in state["resources"]:
        if resource["mode"] != "managed" or resource["type"] != "btp_directory":
            continue
        require(resource.get("module") == "module.directory" and resource["name"] == "this"
                and resource["provider"] == 'provider["registry.terraform.io/sap/btp"]',
                "Unexpected managed directory address/provider; manual state investigation required.")
        for instance in resource["instances"]:
            require(instance.get("index_key") == "project" and not instance.get("deposed")
                    and instance.get("status") != "tainted", "Ambiguous, tainted or deposed directory state; stop.")
            identity = instance["attributes"]["id"]
            require(isinstance(identity, str) and UUID.fullmatch(identity), "Managed directory lacks a valid actual ID.")
            matches.append(identity)
    require(len(matches) <= 1, "Multiple managed directory instances; stop.")
    return matches[0] if matches else ""


def compare_inventory(managed_id, inventory, project_id, name):
    require(isinstance(inventory, list), "Directory inventory must be a complete list.")
    ids = set()
    for directory in inventory:
        require(isinstance(directory, dict) and set(directory) == {"id", "name", "project_ids"},
                "Inventory may contain only ID, name and project IDs.")
        identity = directory["id"]
        require(isinstance(identity, str) and UUID.fullmatch(identity)
                and isinstance(directory["name"], str) and bool(directory["name"])
                and isinstance(directory["project_ids"], list)
                and all(isinstance(p, str) for p in directory["project_ids"]), "Invalid directory inventory row.")
        require(identity not in ids, "Duplicate directory ID in inventory; stop.")
        ids.add(identity)
        collision = directory["name"].lower() == name.lower() or project_id in directory["project_ids"]
        require(identity == managed_id or not collision,
                "Foreign directory has the requested name or project ID; no adoption/import permitted.")
    require(not managed_id or managed_id in ids,
            "State-owned directory is absent from inventory; investigate drift/access, do not recreate automatically.")


def preflight(query, environ, read=read_json):
    require(isinstance(query, dict) and set(query) == {"project_id", "workspace", "name", "inventory"},
            "Preflight requires the fixed query fields; caller-supplied ownership IDs are forbidden.")
    project = query["project_id"]
    require(isinstance(project, str) and re.fullmatch(r"[a-z][a-z0-9]*(?:-[a-z0-9]+)*", project)
            and len(project) <= 40 and project != "project-abc", "Invalid or legacy project ID.")
    workspace = "sap-btp-" + project + "-core"
    require(query["workspace"] == workspace and environ.get("TFC_WORKSPACE_NAME") == workspace,
            "Terraform workspace and HCP run workspace must match the isolated project.")
    name = query["name"]
    require(isinstance(name, str) and 1 <= len(name) <= 255 and "/" not in name, "Invalid directory name.")
    run_id = environ.get("TFC_RUN_ID", "")
    token = environ.get("DIRECTORY_PREFLIGHT_HCP_TOKEN", "")
    require(re.fullmatch(r"run-[A-Za-z0-9]+", run_id) and token,
            "Active directory plans require TFC_RUN_ID and sensitive DIRECTORY_PREFLIGHT_HCP_TOKEN with read-state access.")
    api = lambda path: read(API + path, token=token)["data"]
    run = api("/runs/" + run_id)
    workspace_id = run["relationships"]["workspace"]["data"]["id"]
    require(re.fullmatch(r"ws-[A-Za-z0-9]+", workspace_id)
            and workspace_id == environ.get("TFC_WORKSPACE_ID"), "Run/workspace identity mismatch.")
    require(run["attributes"]["refresh"] is True, "Directory ownership requires a refreshed plan.")
    ws = api("/workspaces/" + workspace_id)
    attrs = ws["attributes"]
    require(attrs["name"] == workspace and attrs["working-directory"] == "BTP/projects"
            and attrs["execution-mode"] in ["remote", "agent"] and attrs["auto-apply"] is False
            and ws["relationships"]["organization"]["data"]["id"] == ORGANIZATION,
            "Unexpected HCP workspace organization, root, execution mode or auto-apply setting.")
    state_ref = ws["relationships"]["current-state-version"]["data"]
    state, version_id = None, ""
    if state_ref is not None:
        version_id = state_ref["id"]
        require(re.fullmatch(r"sv-[A-Za-z0-9]+", version_id), "Invalid state-version identity.")
        version = api("/workspaces/" + workspace_id + "/current-state-version")
        require(version["id"] == version_id, "State changed during preflight; create a fresh plan.")
        state = read(version["attributes"]["hosted-state-download-url"])
        require(state["serial"] == version["attributes"]["serial"], "State serial mismatch; stop.")
    identity = managed_directory_id(state)
    inventory = json.loads(query["inventory"])
    compare_inventory(identity, inventory, project, name)
    # Minimal inventory fields were already supplied in the data-source query.
    # Never return tokens, signed URLs, or any raw state/resource attributes.
    return {"managed_id": identity, "state_version_id": version_id,
            "state_serial": str(state["serial"]) if state else "",
            "state_lineage": state["lineage"] if state else "", "resource_address": ADDRESS,
            "inventory": json.dumps(inventory, sort_keys=True, separators=(",", ":"))}


def main():
    try:
        result = preflight(json.load(sys.stdin), os.environ)
    except PreflightError as error:
        print("Directory ownership preflight: " + str(error), file=sys.stderr)
        return 1
    except (KeyError, TypeError, ValueError, AttributeError):
        print("Directory ownership preflight: incomplete or invalid input/API/state; stop.", file=sys.stderr)
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
