#!/usr/bin/env python3
"""Build/check the versioned YAML contract without Terraform, HCP or credentials."""
from pathlib import Path
import argparse
import json
import math
import os
import tempfile
import yaml
from security_policy import sensitive_key
from validate_landing_zone import ROOT, validate_document

HEADER = (
    "# AUTO-GENERATED – DO NOT EDIT MANUALLY\n"
    "# Quellen: BTP/config/; Build: python scripts/build_landing_zone_config.py\n"
    "# yaml-language-server: $schema=../schemas/landing-zone.schema.json\n"
)
STAGES = ("DEV", "TEST", "PROD")
PROJECT_KEYS = {"schema_version", "account_type", "project_name"}


class ConfigurationError(ValueError):
    """Safe diagnostics: never include input values or YAML parser excerpts."""


class StrictLoader(yaml.SafeLoader):
    def construct_mapping(self, node, deep=False):
        result = {}
        for key_node, value_node in node.value:
            key = self.construct_object(key_node, deep=deep)
            if type(key) is not str:
                raise ConfigurationError("Map-Schlüssel müssen Strings sein")
            if key in result:
                raise ConfigurationError("Doppelter YAML-Schlüssel")
            result[key] = self.construct_object(value_node, deep=deep)
        return result

    def compose_node(self, parent, index):
        # Anchors/aliases/merge keys can conceal duplicate or cyclic structures.
        if self.check_event(yaml.AliasEvent):
            raise ConfigurationError("YAML-Aliase sind nicht zulässig")
        return super().compose_node(parent, index)


def json_values(value):
    """Reject YAML-only types and credentials before serializing anything."""
    if isinstance(value, dict):
        for key, child in value.items():
            if sensitive_key(key):
                raise ConfigurationError("Sensible Schlüssel erfordern HCP-/Laufzeitvariablen")
            json_values(child)
    elif isinstance(value, list):
        for child in value:
            json_values(child)
    elif type(value) not in (str, bool, int, float, type(None)):
        raise ConfigurationError("Nur JSON-kompatible YAML-Datentypen sind zulässig")
    elif type(value) is float and not math.isfinite(value):
        raise ConfigurationError("Zahlen müssen endlich sein")


def load_mapping(path):
    try:
        document = yaml.load(path.read_text(encoding="utf-8"), Loader=StrictLoader)
        if not isinstance(document, dict):
            raise ConfigurationError("Das Dokument muss eine Map sein")
        json_values(document)
        return document
    except ConfigurationError as error:
        raise ConfigurationError(f"{path.name}: {error}") from None
    except (OSError, UnicodeError):
        raise ConfigurationError(f"{path.name}: Datei fehlt oder ist nicht lesbar") from None
    except yaml.YAMLError:
        raise ConfigurationError(f"{path.name}: Ungültige YAML-Syntax (Werte ausgeblendet)") from None


def assemble(config_dir):
    project = load_mapping(config_dir / "project.yaml")
    if set(project) != PROJECT_KEYS:
        raise ConfigurationError("project.yaml: Genau schema_version, account_type und project_name erforderlich")
    catalog = load_mapping(config_dir / "service-catalog.yaml")
    if set(catalog) != {"service_catalog"}:
        raise ConfigurationError("service-catalog.yaml: Genau service_catalog erforderlich")
    environments = load_environments(config_dir)
    # No deep merge, defaults, coercion, interpolation or IAM-policy import.
    document = {**project, **catalog, "environments": environments}
    errors = validate_document(document)
    if errors:
        raise ConfigurationError("Konfiguration verletzt das bestehende Schema:\n" + "\n".join(errors))
    return document


def load_environments(config_dir):
    environments_dir = config_dir / "environments"
    if any(path.name not in {stage.lower() + ".yaml" for stage in STAGES}
           for path in environments_dir.glob("*.y*ml")):
        raise ConfigurationError("environments/: Nur dev.yaml, test.yaml und prod.yaml zulässig")
    environments = {}
    for stage in STAGES:
        name = stage.lower() + ".yaml"
        fragment = load_mapping(environments_dir / name)
        if set(fragment) != {stage} or not isinstance(fragment[stage], dict):
            raise ConfigurationError(f"{name}: Genau die Environment-Map {stage} erforderlich")
        environments[stage] = fragment[stage]
    return environments


def render(document, header=HEADER):
    # Sorting maps removes dependence on source key order; lists retain order.
    text = header + yaml.safe_dump(
        document, allow_unicode=True, sort_keys=True, default_flow_style=False,
        indent=2, width=100, line_break="\n",
    )
    # A type-sensitive round trip catches unintended serialization conversions.
    parsed = yaml.load(text, Loader=StrictLoader)
    if json.dumps(parsed, sort_keys=True) != json.dumps(document, sort_keys=True):
        raise ConfigurationError("YAML-Ausgabe verändert Datentypen oder Werte")
    return text.encode("utf-8")


def build(config_dir, output, check=False):
    content = render(assemble(config_dir))
    write_artifact(content, output, check)


def write_artifact(content, output, check=False):
    try:
        current = output.read_bytes() if output.exists() else None
        if check:
            if current != content:
                raise ConfigurationError(f"{output}: landing-zone.yaml fehlt oder ist veraltet; Build-Skript ausführen")
        elif current != content:
            # Validate entirely before replacing the tracked artifact atomically.
            temporary = None
            try:
                output.parent.mkdir(parents=True, exist_ok=True)
                with tempfile.NamedTemporaryFile(dir=output.parent, delete=False) as stream:
                    temporary = Path(stream.name)
                    stream.write(content)
                temporary.chmod(0o644)
                os.replace(temporary, output)
            finally:
                if temporary is not None:
                    temporary.unlink(missing_ok=True)
    except OSError:
        raise ConfigurationError(f"{output}: Datei kann nicht gelesen/geschrieben werden") from None


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail on missing/stale generated YAML; never write")
    parser.add_argument("--project", help="Build one registered project ID; also validate cross-project isolation")
    args = parser.parse_args()
    # When invoked as __main__, the shared builder helpers are imported under
    # their module name by project_configuration. Catch that same error class.
    from project_configuration import build_projects, ConfigurationError as BuildError
    try:
        build_projects(ROOT, check=args.check, project_id=args.project)
    except BuildError as error:
        raise SystemExit(str(error)) from None
    print("Landing-Zone-Konfiguration: " + ("aktuell und valide." if args.check else "generiert und valide."))


if __name__ == "__main__":
    main()
