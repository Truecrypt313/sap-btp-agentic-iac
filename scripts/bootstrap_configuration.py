"""Validated bootstrap intent and deterministic Terraform registry. No network."""
import json
import re
from pathlib import Path
from build_landing_zone_config import ConfigurationError, ROOT, STAGES, load_mapping, write_artifact
from project_configuration import collect_projects, PROJECT_ID, LEGACY_ID

ARTIFACT = Path("HCP/generated/projects.json")
REQUEST_KEYS = {"schema_version", "project_id", "project_name", "account_profile", "environments", "cf_environments", "directory_name", "spaces"}


def profiles(root):
    document = load_mapping(root / "BTP/config/account-profiles.yaml")
    if set(document) != {"schema_version", "profiles"} or type(document["schema_version"]) is not int or document["schema_version"] != 1:
        raise ConfigurationError("Ungültige Account-Profil-Version")
    entries = document["profiles"]
    if not isinstance(entries, dict) or set(entries) != {"trial"}:
        raise ConfigurationError("Nur das überprüfte Trial-Profil ist derzeit freigegeben")
    profile = entries["trial"]
    expected_keys = {"account_type", "region", "iaas_provider", "environments", "cloud_foundry_plan", "skip_auto_entitlement", "production_allowed"}
    if (not isinstance(profile, dict) or set(profile) != expected_keys or profile["account_type"] != "trial"
            or not isinstance(profile["region"], str) or not re.fullmatch(r"[a-z0-9-]+", profile["region"])
            or profile["iaas_provider"] not in ["AWS", "AZURE"] or profile["environments"] != ["DEV", "TEST"]
            or profile["cloud_foundry_plan"] != "trial" or profile["skip_auto_entitlement"] is not True
            or profile["production_allowed"] is not False):
        raise ConfigurationError("Trial-Profil verletzt den bekannten Entwicklungsvertrag; keine angenommenen Quoten ergänzen")
    return entries


def validate_request(request, root):
    if not isinstance(request, dict) or set(request) != REQUEST_KEYS:
        raise ConfigurationError("Bootstrap-Auftrag enthält fehlende oder unbekannte Felder")
    if type(request["schema_version"]) is not int or request["schema_version"] != 1:
        raise ConfigurationError("Ungültige Bootstrap-Auftragsversion")
    identity = request["project_id"]
    if not isinstance(identity, str) or not re.fullmatch(PROJECT_ID, identity) or len(identity) > 40 or identity == LEGACY_ID:
        raise ConfigurationError("Ungültige oder reservierte Projekt-ID")
    for key in ["project_name", "directory_name"]:
        value = request[key]
        if not isinstance(value, str) or not value.strip() or len(value) > 255 or any(ord(c) < 32 for c in value) or "/" in value:
            raise ConfigurationError("Ungültiger Projekt-/Directory-Anzeigename")
    if not isinstance(request["account_profile"], str) or request["account_profile"] not in profiles(root):
        raise ConfigurationError("Unbekanntes Account-Profil")
    for key in ["environments", "cf_environments"]:
        value = request[key]
        if not isinstance(value, list) or any(type(s) is not str for s in value) or len(value) != len(set(value)) or any(s not in ["DEV", "TEST"] for s in value):
            raise ConfigurationError("Trial erlaubt nur eindeutige DEV-/TEST-Auswahl; PROD bleibt deaktiviert")
    if not request["environments"] or not set(request["cf_environments"]) <= set(request["environments"]):
        raise ConfigurationError("CF-Auswahl muss Teil der angeforderten Umgebungen sein")
    spaces = request["spaces"]
    if not isinstance(spaces, dict) or set(spaces) != set(request["cf_environments"]):
        raise ConfigurationError("Spaces benötigen genau die ausgewählten CF-Umgebungen")
    for values in spaces.values():
        if not isinstance(values, list) or any(not isinstance(s, str) or not re.fullmatch(r"[a-z][a-z0-9-]{0,62}", s) for s in values) or len(values) != len(set(values)):
            raise ConfigurationError("Space-Schlüssel müssen eindeutige technische Namen sein")
    return request


def registry(root):
    projects = collect_projects(root)
    profiles(root)
    result = {}
    for identity, document in projects.items():
        path = root / "BTP/config/projects" / identity / "bootstrap.yaml"
        if not path.exists():
            continue  # Existing prepared projects are never silently registered.
        request = validate_request(load_mapping(path), root)
        if (request["project_id"] != identity or request["project_name"] != document["configuration"]["project_name"]
                or document["configuration"]["account_type"] != "trial" or request["directory_name"] != document["directory"]["name"]):
            raise ConfigurationError("Bootstrap-Auftrag und bestehende Projektidentität widersprechen sich")
        # Operational YAML may later evolve; original request remains the receipt.
        result[identity] = {"account_profile": request["account_profile"], "environments": request["environments"],
                            "cf_environments": request["cf_environments"]}
    return {"schema_version": 1, "projects": result}


def build_registry(root=ROOT, check=False):
    document = registry(root)
    content = (json.dumps(document, indent=2, sort_keys=True, ensure_ascii=False) + "\n").encode()
    path = root / ARTIFACT
    if path.is_symlink() or any(p.is_symlink() for p in [root / "HCP", path.parent]):
        raise ConfigurationError("Bootstrap-Artefakt darf keine Symlinks enthalten")
    write_artifact(content, path, check)
    return document
