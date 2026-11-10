#!/usr/bin/env python3
"""Strict local YAML validation; never contacts SAP, CF or HCP."""
from pathlib import Path
import argparse
import json
import re
import yaml
from jsonschema import Draft202012Validator, FormatChecker
from schema_model import CONFIGURATION
from security_policy import sensitive_key

ROOT = Path(__file__).resolve().parents[1]



def normalize(node, value):
    if value is None:
        value = node["default"]
    if value is None:
        return None
    if node["kind"] == "object":
        return {key: normalize(child, value.get(key)) for key, child in node["properties"].items()}
    if node["kind"] == "map":
        return {key: normalize(node["items"], child) for key, child in value.items()}
    return value


def parameter_checks(node, value, path):
    if value is None:
        return []
    errors = []
    if node.get("json_object"):
        try:
            decoded = json.loads(value)
            if not isinstance(decoded, dict):
                errors.append(path + ": parameters must encode a JSON object")
            def secret_keys(v):
                if isinstance(v, dict):
                    return any(sensitive_key(k) or secret_keys(child) for k, child in v.items())
                return isinstance(v, list) and any(secret_keys(child) for child in v)
            if secret_keys(decoded):
                errors.append(path + ": sensitive parameter keys require a runtime reference")
        except (ValueError, TypeError):
            errors.append(path + ": invalid JSON parameters")
    if node["kind"] == "object":
        if "parameters_key" in node["properties"] and value.get("parameters") is not None and value.get("parameters_key") is not None:
            errors.append(path + ": parameters and parameters_key are mutually exclusive")
        for key, child in node["properties"].items():
            errors.extend(parameter_checks(child, value.get(key), path + "." + key))
    elif node["kind"] == "map":
        for key, child in value.items():
            errors.extend(parameter_checks(node["items"], child, path + ".*"))
    return errors


def validate_document(document):
    schema = json.loads((ROOT / "schemas/landing-zone.schema.json").read_text())
    validator = Draft202012Validator(schema, format_checker=FormatChecker())
    # Do not print error.message: it may contain the invalid value.
    errors = ["/" + "/".join(map(str, e.absolute_path)) + ": " + str(e.validator)
              for e in validator.iter_errors(document)]
    if errors:
        return errors
    config = normalize(CONFIGURATION, document)
    errors.extend(parameter_checks(CONFIGURATION, config, "configuration"))
    for stage, env in config["environments"].items():
        if config["account_type"] == "trial" and stage == "PROD" and env["enabled"]:
            errors.append("environments.PROD: production is prohibited in Trial")
        if env["usage"] == "USED_FOR_PRODUCTION" and (stage != "PROD" or config["account_type"] != "enterprise"):
            errors.append("environments.*.usage: production usage requires enterprise PROD")
        cf = env["cloud_foundry"]
        if cf["enabled"] and (env["runtime"] != "cloudfoundry" or cf["environment_type"] != "cloudfoundry" or cf["service_name"] != "cloudfoundry"):
            errors.append("environments.*.cloud_foundry: incompatible runtime/service")
        if not cf["enabled"] and cf["spaces"]:
            errors.append("environments.*.cloud_foundry: spaces require an enabled CF environment")
        if cf["enabled"] and cf["plan"] != ("trial" if config["account_type"] == "trial" else "standard"):
            errors.append("environments.*.cloud_foundry.plan: profile mismatch")
        if {"stage", "costcenter"} & env["labels"].keys() or len(env["labels"]) > 8:
            errors.append("environments.*.labels: stage/costcenter are reserved, at most eight extra keys")
        for values in env["labels"].values():
            if any(len(value) > 63 for value in values):
                errors.append("environments.*.labels: value exceeds 63 characters")
        collections = env["role_collections"]
        collection_names = [collection["name"] for collection in collections.values()]
        if len(set(collection_names)) != len(collection_names):
            errors.append("environments.*.role_collections: duplicate collection name")
        for collection in collections.values():
            identities = [tuple(role[k] for k in ("name", "role_template_name", "role_template_app_id")) for role in collection["roles"].values()]
            if not collection["name"].strip() or len(set(identities)) != len(identities) or any(not value.strip() for role in identities for value in role):
                errors.append("environments.*.role_collections: blank names or duplicate roles")
        for role in env["role_assignments"].values():
            key, name = role["role_collection_key"], role["role_collection_name"]
            if (key is None) == (name is None) or (key is not None and (key not in collections or role["origin"] is None)) or name in collection_names:
                errors.append("environments.*.role_assignments: use one external name or a managed key with explicit origin")
            subjects = [role["user_name"], role["group_name"], role["attribute_name"]]
            if sum(v is not None for v in subjects) != 1 or (
                role["group_name"] is not None and role["origin"] is None
            ) or (role["attribute_name"] is not None and (role["origin"] is None or role["attribute_value"] is None)) or (
                role["attribute_value"] is not None and role["attribute_name"] is None
            ):
                errors.append("environments.*.role_assignments: invalid subject/origin/attribute combination")
        for space_key, space in cf["spaces"].items():
            if (stage != "DEV" or space_key != "project") and any(space[k] is not None for k in ["legacy_manager", "legacy_developer"]):
                errors.append("environments.*.spaces.*: legacy roles are supported only for DEV/project; use explicit roles")
            if stage == "DEV" and space_key == "project" and space["member_origin"] is not None:
                errors.append("environments.DEV.spaces.project: use legacy_manager/developer.origin or explicit roles, not member_origin")
            roles = list(space["roles"].values()) + [r for r in [space["legacy_manager"], space["legacy_developer"]] if r is not None]
            for role in roles:
                if sum(role[k] is not None for k in ["user", "username"]) != 1 or (role["origin"] is not None and role["username"] is None):
                    errors.append("environments.*.spaces.*.roles: exactly one user/username, origin only with username")
        for key in env["services"]["catalog"]:
            definition = config["service_catalog"].get(key)
            if definition is None or config["account_type"] not in definition["profiles"]:
                errors.append("environments.*.services.catalog: unknown alias or incompatible profile")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="*", type=Path)
    args = parser.parse_args()
    files = args.files or [ROOT / "BTP/landing-zone.yaml", *sorted((ROOT / "examples").glob("landing-zone.*.yaml"))]
    for path in files:
        try:
            document = yaml.safe_load(path.read_text())
        except yaml.YAMLError:
            raise SystemExit(f"{path}: YAML parse error (value omitted)")
        errors = validate_document(document)
        if errors:
            raise SystemExit(str(path) + ":\n" + "\n".join(errors))
        print(f"{path.name}: schema and combination checks passed")


if __name__ == "__main__":
    main()
