#!/usr/bin/env python3
"""Generate/check the YAML schema and Terraform types from schema_model.py."""
from pathlib import Path
import argparse
import json
import re
import subprocess
from schema_model import CONFIGURATION, hcl_type, json_schema
from security_policy import SECRET_KEY_PATTERN

ROOT = Path(__file__).resolve().parents[1]


def constraints(node, expression, depth=0):
    checks = []
    if node.get("json_object"):
        checks.append(f"can(keys(jsondecode({expression})))")
        # Canonicalize JSON first so escaped Unicode key names cannot bypass
        # the credential-key check. The Python validator also walks decoded JSON.
        key_regex = json.dumps(r'"([^"\\]+)"\s*:')
        pattern = json.dumps(SECRET_KEY_PATTERN)
        checks.append(f'alltrue([for key in try(regexall({key_regex}, jsonencode(jsondecode({expression}))), []) : !can(regex({pattern}, replace(key[0], "/[^a-zA-Z0-9]/", "")))])')
    if "enum" in node:
        checks.append(f"contains({json.dumps(node['enum'])}, {expression})")
    if "pattern" in node:
        checks.append(f"can(regex({json.dumps(node['pattern'])}, {expression}))")
    if node.get("format") == "uuid":
        checks.append(f'can(regex("^[0-9a-fA-F]{{8}}-[0-9a-fA-F]{{4}}-[0-9a-fA-F]{{4}}-[0-9a-fA-F]{{4}}-[0-9a-fA-F]{{12}}$", {expression}))')
    for key, op in [("minLength", ">="), ("maxLength", "<=")]:
        if key in node:
            checks.append(f"length({expression}) {op} {node[key]}")
    if "maxProperties" in node:
        checks.append(f"length({expression}) <= {node['maxProperties']}")
    for key, op in [("minimum", ">="), ("maximum", "<=")]:
        if key in node:
            checks.append(f"{expression} {op} {node[key]}")
    if node.get("integer"):
        checks.append(f"floor({expression}) == {expression}")
    if node["kind"] == "object":
        if "parameters" in node["properties"] and "parameters_key" in node["properties"]:
            checks.append(f"!({expression}.parameters != null && {expression}.parameters_key != null)")
        for key, value in node["properties"].items():
            check = constraints(value, expression + "." + key, depth + 1)
            if check:
                checks.append(check)
    elif node["kind"] in ["map", "set"]:
        item = f"item{depth}"
        check = constraints(node["items"], item, depth + 1)
        sequence = f"values({expression})" if node["kind"] == "map" else expression
        checks.append(f"alltrue([for {item} in {sequence} : ({item} != null && ({check or 'true'}))])")
    if not checks:
        return ""
    result = "(" + " &&\n".join(checks) + ")"
    if not node["required"] and node["default"] is None:
        result = f"({expression} == null ? true : {result})"
    return result


def artifacts():
    schema = json_schema(CONFIGURATION)
    schema.update({
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "$id": "https://example.invalid/sap-btp-agentic-iac/landing-zone-v2",
        "title": "SAP BTP Landing Zone v2",
    })
    schema["properties"]["environments"]["propertyNames"] = {"enum": ["DEV", "TEST", "PROD"]}
    schema["properties"]["environments"]["required"] = ["DEV"]
    schema["allOf"] = [{
        "if":{"properties":{"account_type":{"const":"trial"}},"required":["account_type"]},
        "then":{"properties":{"environments":{"properties":{"PROD":{"required":["enabled"],"properties":{"enabled":{"const":False}}}}}}},
    }]
    no_legacy = {"properties": {"legacy_manager": {"type": "null"}, "legacy_developer": {"type": "null"}}}
    def space_policy(selector):
        return {"properties": {"cloud_foundry": {"properties": {"spaces": selector}}}}
    schema["allOf"].append({"properties": {"environments": {
        "patternProperties": {"^(?!DEV$).+$": space_policy({"additionalProperties": no_legacy})},
        "properties": {"DEV": space_policy({"patternProperties": {"^(?!project$).+$": no_legacy}, "properties": {"project": {"properties": {"member_origin": {"type": "null"}}}}})},
    }}})
    main_path = ROOT / "BTP/modules/landing-zone-config/main.tf"
    main = main_path.read_text()
    start = main.index("  type = object(")
    end = main.index("\n\n  validation {", start)
    main = main[:start] + "  type = " + hcl_type(CONFIGURATION) + main[end:]
    main = re.sub(r"\n  # BEGIN GENERATED CONSTRAINTS.*?# END GENERATED CONSTRAINTS\n", "", main, flags=re.S)
    check = constraints(CONFIGURATION, "var.configuration")
    validation = (
        '\n  # BEGIN GENERATED CONSTRAINTS\n'
        '  validation {\n    condition = ' + check +
        '\n    error_message = "A configuration attribute violates its documented type, enum, length, UUID, quota or timeout constraint."\n'
        '  }\n  # END GENERATED CONSTRAINTS\n'
    )
    marker = '\n}\n\noutput "configuration"'
    main = main.replace(marker, validation + marker)
    main = main.replace("Schema v1 of", "Schema v1/v2 of")
    raw_start = "\n# BEGIN GENERATED RAW INPUT\n"
    main = re.sub(r"\n# BEGIN GENERATED RAW INPUT.*?# END GENERATED RAW INPUT\n", "", main, flags=re.S)
    main += raw_start + (
        'variable "raw_configuration" {\n type = any\n default = null\n'
        ' validation {\n condition = try(' + unknown_keys(CONFIGURATION, "var.raw_configuration") +
        ', false)\n error_message = "YAML contains an unknown/read-only attribute or an invalid object shape."\n }\n}\n'
        '# END GENERATED RAW INPUT\n'
    )
    return {
        ROOT / "schemas/landing-zone.schema.json": json.dumps(schema, indent=2) + "\n",
        main_path: main,
    }


def unknown_keys(node, expression, depth=0):
    checks = []
    if node["kind"] == "object":
        checks.append(f"length(setsubtract(toset(keys({expression})), toset({json.dumps(list(node['properties']))}))) == 0")
        for key, child in node["properties"].items():
            if child["kind"] in ["object", "map"]:
                checks.append(unknown_keys(child, f"try({expression}.{key}, null)", depth + 1))
    elif node["kind"] == "map" and node["items"]["kind"] == "object":
        item = f"raw{depth}"
        checks.append(f"alltrue([for {item} in values({expression}) : {unknown_keys(node['items'], item, depth + 1)}])")
    if not checks:
        return "true"
    return f"({expression} == null ? true : (" + " &&\n".join(checks) + "))"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    for path, content in artifacts().items():
        if path.suffix == ".tf":
            content = subprocess.run(["terraform", "fmt", "-"], input=content, text=True, capture_output=True, check=True).stdout
        if args.write:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(content)
        elif path.read_text() != content:
            raise SystemExit(f"Generated schema drift: {path.relative_to(ROOT)}")
    print("Terraform input schema and JSON Schema agree.")


if __name__ == "__main__":
    main()
