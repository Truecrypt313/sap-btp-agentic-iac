"""Separate project envelopes around the unchanged landing-zone v2 contract."""
import json
import re
from jsonschema import Draft202012Validator, FormatChecker
from build_landing_zone_config import (
    ConfigurationError, ROOT, assemble, load_environments, load_mapping,
    render, write_artifact,
)
from validate_landing_zone import validate_document, normalize
from schema_model import CONFIGURATION

PROJECT_ID = r"^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$"
LEGACY_ID = "project-abc"
METADATA_KEYS = {"schema_version", "project_id", "project_name", "account_type", "deployment_enabled"}


def project_schema():
    legacy = json.loads((ROOT / "schemas/landing-zone.schema.json").read_text())
    return {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "title": "Isolated BTP project envelope v1",
        "type": "object", "additionalProperties": False,
        "required": ["project_id", "deployment_enabled", "directory", "configuration"],
        "properties": {
            "project_id": {"type": "string", "pattern": PROJECT_ID, "maxLength": 40, "not": {"const": LEGACY_ID}},
            "deployment_enabled": {"type": "boolean"},
            "directory": {
                "type": "object", "additionalProperties": False,
                "required": ["enabled", "name", "features"],
                "properties": {
                    "enabled": {"type": "boolean"},
                    "name": {"type": "string", "minLength": 1, "maxLength": 255, "pattern": "^[^/]+$"},
                    "description": {"type": ["string", "null"], "maxLength": 300},
                    "features": {"type": "array", "uniqueItems": True, "minItems": 1,
                                 "items": {"enum": ["DEFAULT", "ENTITLEMENTS", "AUTHORIZATIONS"]},
                                 "contains": {"const": "DEFAULT"}},
                },
            },
            "configuration": legacy,
        },
    }


def validate_project(document):
    errors = ["project: " + str(error.validator) for error in
              Draft202012Validator(project_schema(), format_checker=FormatChecker()).iter_errors(document)]
    if errors:
        return errors
    errors.extend(validate_document(document["configuration"]))
    if errors:
        return errors
    directory = document["directory"]
    if "AUTHORIZATIONS" in directory["features"] and "ENTITLEMENTS" not in directory["features"]:
        errors.append("directory.features: AUTHORIZATIONS benötigt ENTITLEMENTS")
    cfg = normalize(CONFIGURATION, document["configuration"])
    for stage, env in cfg["environments"].items():
        prefix = document["project_id"] + "-" + stage.lower()
        if "project_id" in env["labels"] or len(env["labels"]) > 7:
            errors.append("project.environments.labels: project_id reserviert; höchstens sieben Zusatzlabels")
        if (env["parent_id"] is not None or env["administrators_source"] != "yaml" or
                any(space[k] is not None for space in env["cloud_foundry"]["spaces"].values()
                    for k in ["legacy_manager", "legacy_developer"])):
            errors.append("project.environments: Keine externen Parents oder Legacy-IAM-Eingaben")
        if env["name"] is None or env["subdomain"] != prefix or env["cloud_foundry"]["name"] != prefix:
            errors.append("project.environments: Projektgebundene Subaccount-/Org-Identität erforderlich")
        service_names = [instance["name"] for instance in env["services"]["instances"].values()]
        service_names.extend(options["name"] for options in [
            env["services"]["alert_notification"]["instance_options"],
            env["services"]["feature_flags"]["instance_options"],
            *[cfg["service_catalog"][alias]["instance"] for alias in env["services"]["catalog"]
              if cfg["service_catalog"][alias]["instance"] is not None],
        ] if options["name"] is not None)
        if any(not name.startswith(prefix + "-") for name in service_names):
            errors.append("project.services: Instanznamen benötigen Projekt-/Stage-Präfix")
    return errors


def assemble_project(root, project_dir):
    if any(path.is_symlink() for path in project_dir.rglob("*")):
        raise ConfigurationError("Projektquellen dürfen keine Symlinks enthalten")
    metadata = load_mapping(project_dir / "project.yaml")
    if set(metadata) != METADATA_KEYS:
        raise ConfigurationError("project.yaml: Projektmetadaten unvollständig oder unbekannt")
    project_id = metadata["project_id"]
    if type(metadata["project_name"]) is not str:
        raise ConfigurationError("project.yaml: project_name muss ein String sein")
    if (type(project_id) is not str or not re.fullmatch(PROJECT_ID, project_id)
            or len(project_id) > 40 or project_id != project_dir.name or project_id == LEGACY_ID):
        raise ConfigurationError("project.yaml: Stabile, nicht reservierte Projekt-ID muss dem Verzeichnis entsprechen")
    directory = load_mapping(project_dir / "directory.yaml")
    if set(directory) != {"directory"}:
        raise ConfigurationError("directory.yaml: Genau directory erforderlich")
    catalog = load_mapping(root / "BTP/config/service-catalog.yaml")
    if set(catalog) != {"service_catalog"}:
        raise ConfigurationError("service-catalog.yaml: Genau service_catalog erforderlich")
    environments = load_environments(project_dir)
    for stage, env in environments.items():
        # Explicit enable flags are mandatory for new project sources.
        if type(env.get("enabled")) is not bool:
            raise ConfigurationError("project.environments: enabled muss explizites Boolean sein")
        prefix = project_id + "-" + stage.lower()
        env.setdefault("name", metadata["project_name"] + " " + stage)
        env.setdefault("subdomain", prefix)
        cf = env.setdefault("cloud_foundry", {})
        if isinstance(cf, dict):
            cf.setdefault("name", prefix)
    document = {
        "project_id": project_id, "deployment_enabled": metadata["deployment_enabled"],
        **directory,
        "configuration": {
            **{key: metadata[key] for key in ["schema_version", "account_type", "project_name"]},
            **catalog, "environments": environments,
        },
    }
    errors = validate_project(document)
    if errors:
        raise ConfigurationError("Projektkonfiguration ungültig:\n" + "\n".join(errors))
    return document


def check_collisions(legacy, projects):
    # Reserve identities even for disabled stages/projects. Existing legacy UUID
    # subdomains are not guessed; new subdomains always end in a stage suffix.
    seen = {}
    def reserve(kind, value, owner):
        if value is None:
            return
        key = (kind, value.casefold())
        if key in seen and seen[key] != owner:
            raise ConfigurationError("Projektübergreifende Namens-/Subdomain-Kollision (Wert ausgeblendet)")
        seen[key] = owner
    for project_id, configuration, directory in [(LEGACY_ID, legacy, None), *[
        (p["project_id"], p["configuration"], p["directory"]) for p in projects.values()
    ]]:
        if directory is not None:
            reserve("directory", directory["name"], project_id)
        config = normalize(CONFIGURATION, configuration)
        for stage, env in config["environments"].items():
            owner = project_id + "/" + stage
            reserve("subaccount_name", env["name"] or f"{stage} {config['project_name']}", owner)
            reserve("subdomain", env["subdomain"], owner)
            reserve("org", env["cloud_foundry"]["name"] or env["subdomain"], owner)
            prefix = project_id + "-" + stage.lower()
            services = env["services"]
            instances = list(services["instances"].values())
            for key in ["alert_notification", "feature_flags"]:
                preset = services[key]
                if preset["enabled"] and preset["instance"]:
                    instances.append({"name": preset["instance_options"]["name"] or prefix + "-" + key.replace("_", "-")})
            for alias in services["catalog"]:
                entry = config["service_catalog"][alias]
                if entry["instance"] is not None:
                    instances.append({"name": entry["instance"]["name"] or prefix + "-" + alias})
            for instance in instances:
                reserve("instance", instance["name"], owner)


def collect_projects(root):
    parent = root / "BTP/config/projects"
    projects = {}
    if parent.exists():
        for path in sorted(parent.iterdir()):
            if not path.is_dir() or path.is_symlink():
                raise ConfigurationError("projects/: Nur reguläre Projektverzeichnisse zulässig")
            document = assemble_project(root, path)
            projects[document["project_id"]] = document
    check_collisions(assemble(root / "BTP/config"), projects)
    return projects


def project_header(project_id):
    return ("# AUTO-GENERATED – DO NOT EDIT MANUALLY\n"
            f"# Quelle: BTP/config/projects/{project_id}/; zentraler Service-Katalog\n"
            "# yaml-language-server: $schema=../../../schemas/project.schema.json\n")


def build_projects(root, check=False, project_id=None):
    # Validate the whole registry before any write, including single-project builds.
    projects = collect_projects(root)
    if project_id is not None and project_id not in projects:
        raise ConfigurationError("Unbekannte Projekt-ID")
    outputs = root / "BTP/generated"
    if outputs.is_symlink() or (outputs.exists() and any(path.is_symlink() for path in outputs.rglob("*"))):
        raise ConfigurationError("Projektartefakte dürfen keine Symlinks enthalten")
    if outputs.exists() and any(path.name not in projects for path in outputs.iterdir()):
        raise ConfigurationError("generated/: Nicht zugeordnetes oder veraltetes Projektartefakt")
    if project_id is None:
        write_artifact(render(assemble(root / "BTP/config")), root / "BTP/landing-zone.yaml", check)
    for key, document in projects.items():
        if project_id is None or key == project_id:
            write_artifact(render(document, project_header(key)), outputs / key / "landing-zone.yaml", check)
