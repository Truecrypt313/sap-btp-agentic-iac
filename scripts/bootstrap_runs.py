#!/usr/bin/env python3
"""GitOps run orchestration only. Workspace/variable/permission CRUD is Terraform."""
import argparse
import json
import os
import re
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.request import Request, build_opener

from bootstrap_configuration import build_registry
from build_landing_zone_config import ROOT, ConfigurationError
from directory_ownership_preflight import NoRedirect, API

ORG = "sap-ai-landing-zone"
REPO = "Truecrypt313/sap-btp-agentic-iac"


def require(condition, message):
    if not condition:
        raise ConfigurationError(message)


class HCP:
    def __init__(self):
        self.token = os.environ.get("HCP_ORCHESTRATION_TOKEN")
        require(bool(self.token), "HCP_ORCHESTRATION_TOKEN als sensitive Laufzeitvariable erforderlich")

    def call(self, method, path, payload=None):
        # No second infrastructure manager, DELETE, imports, credentials or state writes.
        require(method == "GET" or (method == "POST" and (path == "/runs" or re.fullmatch(r"/runs/run-[A-Za-z0-9]+/actions/apply", path))),
                "Nur lesende API-Aufrufe, Run-Planung und ausdrücklich freigegebene Run-Bestätigung erlaubt")
        require(path.startswith("/") and ".." not in path and "?" not in path, "Ungültiger fester HCP-API-Pfad")
        request = Request(API + path, method=method, data=None if payload is None else json.dumps(payload).encode(),
                          headers={"Authorization": "Bearer " + self.token, "Content-Type": "application/vnd.api+json"})
        try:
            with build_opener(NoRedirect()).open(request, timeout=30) as response:
                body = response.read(4 * 1024 * 1024 + 1)
            require(len(body) <= 4 * 1024 * 1024, "Unerwartet große HCP-Antwort")
            return json.loads(body) if body else {}
        except HTTPError as error:
            raise ConfigurationError(f"HCP-Schritt fehlgeschlagen (HTTP {error.code}); Rechte, VCS-Autorisierung, Workspace-Konflikte und Plattform-Setup prüfen. Keine automatische Übernahme.") from None
        except (URLError, OSError, ValueError):
            raise ConfigurationError("HCP nicht erreichbar oder Antwort ungültig; keinen Apply wiederholen, zuerst Run-Status prüfen") from None


def target(phase, project=None, environment=None, root=ROOT):
    if phase == "bootstrap":
        require(project is None and environment is None, "Bootstrap besitzt einen eigenen, projektunabhängigen State")
        return "sap-btp-project-bootstrap", "HCP/bootstrap"
    registered = build_registry(root, check=True)["projects"]
    require(project in registered, "Nur ausdrücklich registrierte neue Projekte orchestrieren; niemals Project ABC")
    if phase == "core":
        require(environment is None, "BTP-Core enthält keinen CF-Environment-Input")
        return f"sap-btp-{project}-core", "BTP/projects"
    require(phase == "cf" and environment in registered[project]["cf_environments"], "Nur registrierte CF-Umgebungen auswählen")
    return f"sap-btp-{project}-cf-{environment.lower()}", "CloudFoundry/projects"


def workspace(client, name, directory):
    ws = client.call("GET", f"/organizations/{ORG}/workspaces/{name}")["data"]
    a = ws["attributes"]
    require(a["name"] == name and a["working-directory"] == directory and a["auto-apply"] is False
            and a["terraform-version"] == "1.15.5" and a["execution-mode"] == "remote"
            and a["vcs-repo"]["identifier"] == REPO and a["vcs-repo"]["branch"] == "main"
            and ws["relationships"]["organization"]["data"]["id"] == ORG,
            "Workspace-Einstellungen passen nicht zum freigegebenen GitOps-Ziel")
    require(re.fullmatch(r"ws-[A-Za-z0-9]+", ws["id"]), "Ungültige Workspace-ID")
    return ws


def verify_version(client, version, commit):
    require(re.fullmatch(r"[0-9a-f]{40}", commit or "") and re.fullmatch(r"cv-[A-Za-z0-9]+", version or ""), "Exakte Commit- und Konfigurationsversion erforderlich")
    ingress = client.call("GET", f"/configuration-versions/{version}/ingress-attributes")["data"]["attributes"]
    require(ingress["commit-sha"] == commit and ingress["branch"] == "main" and ingress["is-pull-request"] is False,
            "Nur exakt passende, nach main gemergte VCS-Konfiguration verwenden; auf den VCS-Ingress warten")


def verify_managed_workspace(client, ws, phase, project, environment):
    if phase == "bootstrap":
        return  # One-time platform workspace, explicitly configured outside this state.
    bootstrap = workspace(client, "sap-btp-project-bootstrap", "HCP/bootstrap")
    outputs = client.call("GET", "/workspaces/" + bootstrap["id"] + "/current-state-version-outputs")["data"]
    matching = [item["attributes"] for item in outputs if item["attributes"]["name"] == "project_workspace_ids"]
    key = project + ("/core" if phase == "core" else "/cf/" + environment)
    require(len(matching) == 1 and matching[0]["sensitive"] is False and matching[0]["value"].get(key) == ws["id"],
            "Ziel-Workspace ist nicht durch den tatsächlichen Bootstrap-State belegt; keine fremden Workspaces übernehmen")


def plan(client, phase, commit, project=None, environment=None, allow_apply=False, root=ROOT, configuration_version=None):
    name, directory = target(phase, project, environment, root)
    ws = workspace(client, name, directory)
    verify_managed_workspace(client, ws, phase, project, environment)
    version = configuration_version or ws["relationships"]["current-configuration-version"]["data"]["id"]
    verify_version(client, version, commit)
    # A VCS webhook may already have queued the same normal plan. Reuse only
    # its exact version/workspace and safe options, never an unrelated run.
    current = ws["relationships"].get("current-run", {}).get("data")
    if allow_apply and current:
        require(re.fullmatch(r"run-[A-Za-z0-9]+", current["id"]), "Ungültige aktuelle Run-ID")
        candidate = client.call("GET", "/runs/" + current["id"])["data"]
        a, rel = candidate["attributes"], candidate["relationships"]
        terminal = {"applied", "planned_and_finished", "errored", "canceled", "force_canceled", "discarded", "policy_soft_failed"}
        if (rel["workspace"]["data"]["id"] == ws["id"] and rel["configuration-version"]["data"]["id"] == version
                and a["status"] not in terminal and a["plan-only"] is False and a["auto-apply"] is False
                and a["refresh"] is True and a["is-destroy"] is False
                and not any(a.get(key) for key in ["target-addrs", "replace-addrs", "variables", "invoke-action-addrs", "refresh-only", "save-plan"])):
            return {"workspace": name, "run_id": candidate["id"], "commit": commit, "plan_only": False, "reused": True}
    payload = {"data": {"type": "runs", "attributes": {
        "message": f"GitOps {phase}: {name} @ {commit}", "plan-only": not allow_apply, "refresh": True, "is-destroy": False,
        "auto-apply": False,
    }, "relationships": {"workspace": {"data": {"type": "workspaces", "id": ws["id"]}},
                          "configuration-version": {"data": {"type": "configuration-versions", "id": version}}}}}
    run = client.call("POST", "/runs", payload)["data"]
    require(re.fullmatch(r"run-[A-Za-z0-9]+", run["id"]), "HCP lieferte keine gültige Run-ID")
    return {"workspace": name, "run_id": run["id"], "commit": commit, "plan_only": not allow_apply, "reused": False}


def inspect_run(client, run_id, name, directory, commit, phase, project, environment):
    require(re.fullmatch(r"run-[A-Za-z0-9]+", run_id or ""), "Ungültige Run-ID")
    run = client.call("GET", "/runs/" + run_id)["data"]
    ws = workspace(client, name, directory)
    verify_managed_workspace(client, ws, phase, project, environment)
    attrs = run["attributes"]
    require(run["relationships"]["workspace"]["data"]["id"] == ws["id"] and attrs["is-destroy"] is False
            and attrs["refresh"] is True and attrs["auto-apply"] is False and not attrs.get("target-addrs") and not attrs.get("replace-addrs")
            and not attrs.get("invoke-action-addrs") and not attrs.get("variables") and not attrs.get("refresh-only"),
            "Run-Ziel oder Optionen widersprechen der vollständigen, geprüften GitOps-Konfiguration")
    verify_version(client, run["relationships"]["configuration-version"]["data"]["id"], commit)
    return run


def wait(client, run_id, wanted, phase, timeout=900, pause=time.sleep, now=time.monotonic):
    deadline = now() + timeout
    failures = {"errored", "canceled", "force_canceled", "discarded", "policy_soft_failed", "policy_override"}
    while now() < deadline:
        run = client.call("GET", "/runs/" + run_id)["data"]
        status = run["attributes"]["status"]
        if status in wanted:
            return run
        if status in failures:
            context = "SAP-BTP: Account-Fähigkeiten, Berechtigungen und tatsächliche Entitlements/Quoten im privaten Run prüfen; keine Quoten automatisch verschieben" if phase == "core" else "HCP/CF: Berechtigungen, Workspace-Konflikte, Credentials und gültigen BTP-Handoff im privaten Run prüfen"
            raise ConfigurationError(f"Terraform-Run abgebrochen ({status}). {context}.")
        pause(3)
    raise ConfigurationError("HCP-Wartezeit überschritten; Run zuerst prüfen, keinen Apply blind wiederholen")


def approve(client, phase, commit, run_id, approval, project=None, environment=None, root=ROOT):
    name, directory = target(phase, project, environment, root)
    require(approval == f"apply:{name}:{run_id}:{commit}", "Explizite Freigabe muss Workspace, Run-ID und Commit exakt nennen")
    run = inspect_run(client, run_id, name, directory, commit, phase, project, environment)
    attrs = run["attributes"]
    require(attrs["plan-only"] is False and attrs["actions"]["is-confirmable"] is True
            and attrs["status"] in {"planned", "policy_checked", "cost_estimated", "post_plan_completed"},
            "Nur einen fertig geprüften, noch nicht bestätigten Apply-fähigen Run freigeben")
    metadata = client.call("GET", "/plans/" + run["relationships"]["plan"]["data"]["id"])["data"]["attributes"]
    require(metadata["status"] == "finished" and metadata["resource-destructions"] == 0
            and metadata["resource-imports"] == 0 and metadata.get("action-invocations", 0) == 0,
            "Destroy, Replace, Import oder zusätzliche Actions sind in diesem Bootstrap-Workflow nicht freigegeben")
    client.call("POST", "/runs/" + run_id + "/actions/apply", {"comment": "Explicit GitOps approval for " + commit})
    wait(client, run_id, {"applied"}, phase)
    drift = plan(client, phase, commit, project, environment, root=root,
                 configuration_version=run["relationships"]["configuration-version"]["data"]["id"])
    result = wait(client, drift["run_id"], {"planned_and_finished"}, phase)
    require(result["attributes"]["has-changes"] is False, "Folgeplan meldet Drift; keine automatische Korrektur")
    return {"workspace": name, "applied_run": run_id, "drift_run": drift["run_id"], "drift": False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for command in ["plan", "approve"]:
        p = commands.add_parser(command)
        p.add_argument("--phase", choices=["bootstrap", "core", "cf"], required=True)
        p.add_argument("--project-id")
        p.add_argument("--environment", choices=["DEV", "TEST", "PROD"])
        p.add_argument("--commit", required=True)
        if command == "plan":
            p.add_argument("--allow-apply", action="store_true", help="Queue a normal plan with auto-apply off; default is plan-only")
        else:
            p.add_argument("--run-id", required=True)
            p.add_argument("--approval", required=True)
    commands.add_parser("projects")
    args = parser.parse_args()
    try:
        if args.command == "projects":
            result = sorted(build_registry(ROOT, check=True)["projects"])
        else:
            client = HCP()
            if args.command == "plan":
                result = plan(client, args.phase, args.commit, args.project_id, args.environment, args.allow_apply)
            else:
                result = approve(client, args.phase, args.commit, args.run_id, args.approval, args.project_id, args.environment)
        print(json.dumps(result, sort_keys=True))
    except ConfigurationError as error:
        print(str(error), file=sys.stderr)
        return 1
    except (KeyError, TypeError, ValueError, OSError):
        print("Unvollständiger GitOps-/API-Kontext; keine Infrastrukturänderung freigeben", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
