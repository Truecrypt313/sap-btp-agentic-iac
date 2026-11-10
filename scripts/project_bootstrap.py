#!/usr/bin/env python3
"""Project bootstrap CLI; importable functions are also the future API boundary."""
import argparse
from contextlib import contextmanager
from copy import deepcopy
import fcntl
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

from build_landing_zone_config import ConfigurationError, ROOT, STAGES, load_mapping, render, write_artifact
from project_configuration import build_projects, collect_projects
from bootstrap_configuration import ARTIFACT, build_registry, profiles, validate_request


@contextmanager
def repository_lock(root):
    path = root / ".project-bootstrap.lock"
    fd = os.open(path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    with os.fdopen(fd, "w") as stream:
        fcntl.flock(stream, fcntl.LOCK_EX)
        yield


def source(document):
    header = "# Bearbeitbare Projektquelle; automatisch vorbereitet, keine Bereitstellung.\n"
    if set(document) <= set(STAGES):
        header += ("# Projekt und Umgebung bleiben deaktiviert (Boolean false). Erst nach eigenem PR/Plan aktivieren.\n"
                   "# CF-enabled ist bei ausgewähltem CF nur die vorbereitete Absicht; beide Elternschalter bleiben aus.\n"
                   "# Spaces brauchen laut Schema CF-enabled; Namen sind stabile for_each-Schlüssel.\n"
                   "# costcenter: fünfstelliger String für Metadaten, keine Budget-/Quotenzusage.\n"
                   "# Region/Provider: Profilvorgaben; Änderungen können Ressourcen ersetzen.\n"
                   "# skip_auto_entitlement: true vor Erstellung unterdrückt automatische Standardpläne.\n"
                   "# Spätere Änderung benötigt laut Provider Ersatz; prevent_destroy blockiert diesen.\n"
                   "# Leere IAM-/Administratorlisten vergeben keine Rechte; BTP-IAM und CF-Rollen sind getrennt.\n"
                   "# Explizite Benutzer-/Gruppenzuweisungen brauchen die richtige Identity-Provider-Origin.\n"
                   "# Leerer Service-Katalog aktiviert keine Entitlements/Instanzen/Subscriptions.\n")
    elif "directory" in document:
        header += ("# enabled: false vor Erstellung. Nach Erstellung true beibehalten; nie auf existing-ID umschalten.\n"
                   "# DEFAULT erzeugt keinen eigenen Quotenbereich. Parent/Ownership werden live geprüft.\n"
                   "# Änderungen an Parent/Features können Ersatz oder neue Berechtigungen erfordern.\n")
    elif "deployment_enabled" in document:
        header += "# Projekt-ID ist unveränderliche State-/Workspace-Identität; Anzeigename ist keine ID.\n# deployment_enabled: false sperrt alle Projektressourcen, auch vorbereitete CF-Absichten.\n"
    else:
        header += "# Bootstrap-Auftragsbeleg: ursprüngliche Absicht für HCP, keine SAP-Aktivierung.\n# Listen und Spaces werden kanonisch sortiert. Identische Wiederholung überschreibt nichts.\n"
    return render(document, header)


def request_from_args(args):
    stages = args.environments.split(",")
    cf = args.cf_environments.split(",") if args.cf_environments else []
    spaces = {stage: [] for stage in cf}
    for entry in args.space:
        stage, separator, name = entry.partition("=")
        if not separator or stage not in spaces:
            raise ConfigurationError("--space verlangt STAGE=schluessel einer ausgewählten CF-Umgebung")
        spaces[stage].append(name)
    return {"schema_version": 1, "project_id": args.project_id, "project_name": args.project_name,
            "account_profile": args.account_profile, "environments": stages, "cf_environments": cf,
            "directory_name": args.directory_name or args.project_name.replace(" ", "_"), "spaces": spaces}


def prepare_project(request, root=ROOT, register_existing=False):
    """Validate in isolation, then install only new sources/artifact + registry."""
    request = validate_request(deepcopy(request), root)
    # Lists are sets of selected stages/names, stored in canonical order.
    for key in ["environments", "cf_environments"]:
        request[key] = [s for s in STAGES if s in request[key]]
    request["spaces"] = {s: sorted(v) for s, v in sorted(request["spaces"].items())}
    with repository_lock(root):
        projects = collect_projects(root)
        build_projects(root, check=True)
        build_registry(root, check=True)
        target = root / "BTP/config/projects" / request["project_id"]
        receipt = target / "bootstrap.yaml"
        if receipt.exists():
            if load_mapping(receipt) != request:
                raise ConfigurationError("Projekt existiert mit anderem Bootstrap-Auftrag; keine Überschreibung")
            build_projects(root, check=True)
            build_registry(root, check=True)
            return {"project_id": request["project_id"], "status": "unchanged"}
        if target.exists() and not register_existing:
            raise ConfigurationError("Bestehendes Projekt wird nicht übernommen; ausdrücklich register verwenden")
        if register_existing and request["project_id"] not in projects:
            raise ConfigurationError("register benötigt ein bereits vorhandenes, geprüftes Projekt")
        if register_existing:
            doc = projects[request["project_id"]]
            if doc["deployment_enabled"] or doc["directory"]["enabled"] or any(env["enabled"] or env["cloud_foundry"]["enabled"] for env in doc["configuration"]["environments"].values()):
                raise ConfigurationError("Nur vollständig deaktivierte bestehende Projekte können registriert werden; keine Ressourcenadoption")
        with tempfile.TemporaryDirectory(prefix="project-bootstrap-") as tmp:
            stage = Path(tmp)
            shutil.copytree(root / "BTP/config", stage / "BTP/config")
            staged = stage / "BTP/config/projects" / request["project_id"]
            if not register_existing:
                staged.mkdir(parents=True, exist_ok=False)
                profile = profiles(root)[request["account_profile"]]
                metadata = load_mapping(root / "templates/project/project.yaml")
                metadata.update(project_id=request["project_id"], project_name=request["project_name"], account_type=profile["account_type"])
                metadata["deployment_enabled"] = False
                directory = load_mapping(root / "templates/project/directory.yaml")
                directory["directory"].update(name=request["directory_name"], description="Vorbereitetes Projekt " + request["project_name"])
                directory["directory"]["enabled"] = False
                (staged / "project.yaml").write_bytes(source(metadata))
                (staged / "directory.yaml").write_bytes(source(directory))
                for s in STAGES:
                    env = load_mapping(root / "templates/project/environment.yaml")
                    env.update(region=profile["region"], iaas_provider=profile["iaas_provider"], skip_auto_entitlement=profile["skip_auto_entitlement"])
                    env["enabled"] = False
                    # Existing schema requires enabled CF for configured spaces.
                    # This is prepared intent only: project AND stage stay off.
                    env["cloud_foundry"]["enabled"] = s in request["cf_environments"]
                    env["cloud_foundry"]["plan"] = profile["cloud_foundry_plan"] if s != "PROD" else "standard"
                    env["cloud_foundry"]["spaces"] = {name: {"name": name} for name in request["spaces"].get(s, [])}
                    (staged / "environments").mkdir(exist_ok=True)
                    (staged / "environments" / (s.lower() + ".yaml")).write_bytes(source({s: env}))
                (staged / "iam").mkdir()
                shutil.copyfile(root / "templates/project/policies.yaml", staged / "iam/policies.yaml")
            (staged / "bootstrap.yaml").write_bytes(source(request))
            build_projects(stage, project_id=request["project_id"])
            build_registry(stage)
            # All conflicts/schema checks happen before the first repository mutation.
            old_registry = (root / ARTIFACT).read_bytes() if (root / ARTIFACT).exists() else None
            artifact = root / "BTP/generated" / request["project_id"] / "landing-zone.yaml"
            if not register_existing and artifact.parent.exists():
                raise ConfigurationError("Nicht zugeordnetes Projektartefakt existiert; keine Überschreibung")
            target_created = artifact_created = receipt_created = False
            try:
                if register_existing:
                    build_projects(root, check=True)
                    with receipt.open("xb") as stream:
                        receipt_created = True
                        stream.write((staged / "bootstrap.yaml").read_bytes())
                else:
                    artifact.parent.mkdir(parents=True, exist_ok=False)
                    artifact_created = True
                    target.mkdir(parents=True, exist_ok=False)
                    target_created = True
                    shutil.copytree(staged, target, dirs_exist_ok=True)
                    write_artifact((stage / "BTP/generated" / request["project_id"] / "landing-zone.yaml").read_bytes(), artifact, False)
                write_artifact((stage / ARTIFACT).read_bytes(), root / ARTIFACT, False)
            except (OSError, ConfigurationError):
                if register_existing:
                    if receipt_created:
                        receipt.unlink(missing_ok=True)
                else:
                    if target_created:
                        shutil.rmtree(target, ignore_errors=True)
                    if artifact_created:
                        shutil.rmtree(artifact.parent, ignore_errors=True)
                if old_registry is not None:
                    write_artifact(old_registry, root / ARTIFACT, False)
                raise ConfigurationError("Projektvorbereitung fehlgeschlagen; Änderungen zurückgerollt") from None
    return {"project_id": request["project_id"], "status": "registered" if register_existing else "created"}


def prepare_pr(identity, root=ROOT, publish=False):
    """Git operations only; never include unrelated worktree or branch changes."""
    registry = build_registry(root, check=True)["projects"]
    if identity not in registry:
        raise ConfigurationError("Nur registrierte Projekte erhalten einen Bootstrap-PR")
    allowed = lambda p: p == str(ARTIFACT) or p.startswith(f"BTP/config/projects/{identity}/") or p == f"BTP/generated/{identity}/landing-zone.yaml"
    def git(*args):
        result = subprocess.run(["git", *args], cwd=root, capture_output=True, text=True)
        if result.returncode:
            raise ConfigurationError("Git-Schritt fehlgeschlagen; keine fremden Änderungen übernehmen")
        return result.stdout.strip()
    tracked = git("diff", "--name-only", "HEAD").splitlines()
    untracked = git("ls-files", "--others", "--exclude-standard").splitlines()
    if any(not allowed(p) for p in tracked + untracked):
        raise ConfigurationError("Fremde lokale Änderungen vorhanden; PR-Vorbereitung abgebrochen")
    # Scan before the first commit/push, not merely in CI after publication.
    from run_secret_scan import scan_repository
    try:
        scan_repository(root, base="origin/main")
    except (SystemExit, OSError, subprocess.CalledProcessError):
        raise ConfigurationError("Secret-/Dateischutz fehlgeschlagen; kein Projekt-Commit oder Push erstellt") from None
    branch = "bootstrap/" + identity
    current = git("branch", "--show-current")
    if current != branch:
        if git("rev-parse", "HEAD") != git("rev-parse", "origin/main"):
            raise ConfigurationError("Neuen Projekt-PR auf synchronisiertem origin/main beginnen")
        git("switch", "-c", branch)
    if any(not allowed(p) for p in git("diff", "--name-only", "origin/main...HEAD").splitlines()):
        raise ConfigurationError("Feature-Branch enthält fremde Änderungen")
    git("add", "--", f"BTP/config/projects/{identity}", f"BTP/generated/{identity}/landing-zone.yaml", str(ARTIFACT))
    if git("diff", "--cached", "--name-only"):
        git("commit", "-m", "feat: prepare isolated project " + identity)
    result = {"branch": branch, "commit": git("rev-parse", "HEAD")}
    if publish:
        git("push", "-u", "origin", branch)
        def gh(*args):
            r = subprocess.run(["gh", *args], cwd=root, capture_output=True, text=True)
            if r.returncode:
                raise ConfigurationError("GitHub-PR-Schritt fehlgeschlagen; keine Zugangsdaten ausgeben")
            return r.stdout.strip()
        existing = json.loads(gh("pr", "list", "--head", branch, "--base", "main", "--state", "open", "--json", "url"))
        result["url"] = existing[0]["url"] if existing else gh("pr", "create", "--base", "main", "--head", branch,
            "--title", "Prepare project " + identity, "--body", "Prepare isolated project configuration and HCP bootstrap intent. All SAP deployment switches remain disabled. Infrastructure requires separate approval.")
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ["create", "register"]:
        p = commands.add_parser(name)
        for field in ["project-id", "project-name", "account-profile", "environments"]:
            p.add_argument("--" + field, required=True)
        p.add_argument("--directory-name")
        p.add_argument("--cf-environments", default="")
        p.add_argument("--space", action="append", default=[])
    commands.add_parser("build")
    commands.add_parser("check")
    p = commands.add_parser("pr")
    p.add_argument("--project-id", required=True)
    p.add_argument("--publish", action="store_true")
    args = parser.parse_args()
    try:
        if args.command in ["create", "register"]:
            result = prepare_project(request_from_args(args), register_existing=args.command == "register")
        elif args.command == "pr":
            result = prepare_pr(args.project_id, publish=args.publish)
        else:
            build_projects(ROOT, check=args.command == "check")
            result = build_registry(ROOT, check=args.command == "check")
        print(json.dumps(result, sort_keys=True))
    except ConfigurationError as error:
        print(str(error), file=sys.stderr)
        return 1
    except (OSError, ValueError, TypeError):
        # Never include exception excerpts, command output, URLs with auth or secrets.
        print("Projekt-Bootstrap fehlgeschlagen; Konfiguration, Konflikte, generierte Dateien und lokalen Git-Stand prüfen. Bestehende Projekte werden nicht überschrieben.", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
