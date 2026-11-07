"""Single model for generated Terraform input types and strict JSON Schema.

Provider fields/types are audited against schemas/provider-resources.json.
Routing fields and template policies are explicitly separate from provider fields.
"""
import json


def field(kind="string", default=None, required=False, description="", **kwargs):
    return dict(kind=kind, default=default, required=required, description=description, **kwargs)


def obj(properties, **kwargs):
    return field("object", properties=properties, **kwargs)


def mapping(items, **kwargs):
    return field("map", items=items, **kwargs)


def strings(default=None, **kwargs):
    return field("set", items=field(), default=default, **kwargs)


TIMEOUTS = obj({key: field(pattern=r"^([0-9]+(\.[0-9]+)?(ns|us|ms|s|m|h))+$")
                for key in ["create", "update", "delete"]})
BTP_LABELS = mapping(field("set", items=field(maxLength=63)), default={}, maxProperties=8)
CF_LABELS = mapping(field())
INSTANCE_OPTIONS = obj({
    "name": field(),
    "parameters": field(description="Non-secret JSON object; secrets use parameters_key.", json_object=True),
    "parameters_key": field(description="Key into sensitive runtime instance_parameters, never a secret value."),
    "labels": mapping(strings()),
    "shared": field("bool"),
    "serviceplan_id": field(description="Optional actual catalog ID; checked against the named catalog lookup."),
    "use_plan_names": field("bool", default=False),
    "required_platform": field(description="Required supported_platforms entry from the actual service plan."),
    "timeouts": TIMEOUTS,
})
SUBSCRIPTION_OPTIONS = obj({
    "parameters": field(description="Non-secret JSON object.", json_object=True),
    "parameters_key": field(description="Key into sensitive runtime subscription_parameters."),
    "timeouts": TIMEOUTS,
})
ENTITLEMENT = obj({
    "service_name": field(required=True),
    "plan_name": field(required=True),
    "amount": field("number", minimum=1, maximum=2000000000, integer=True),
    "plan_unique_identifier": field(),
})
INSTANCE = obj({
    **INSTANCE_OPTIONS["properties"],
    "offering": field(required=True),
    "plan": field(required=True),
    "name": field(required=True),
})
SUBSCRIPTION = obj({
    **SUBSCRIPTION_OPTIONS["properties"],
    "app_name": field(required=True),
    "plan_name": field(required=True),
})
BTP_ROLE = obj({
    "role_collection_name": field(required=True, minLength=1),
    "user_name": field(minLength=1, maxLength=256),
    "group_name": field(minLength=1),
    "attribute_name": field(minLength=1),
    "attribute_value": field(minLength=1),
    "origin": field(minLength=1),
})
CF_ROLE = obj({
    "type": field(required=True, enum=["space_manager", "space_developer", "space_auditor", "space_supporter"]),
    "user": field(format="uuid"),
    "username": field(minLength=1),
    "origin": field(),
})
LEGACY_CF_ROLE = obj({k: v for k, v in CF_ROLE["properties"].items() if k != "type"})
SPACE = obj({
    "name": field(required=True, minLength=1),
    "allow_ssh": field("bool"),
    "isolation_segment": field(format="uuid"),
    "labels": CF_LABELS,
    "annotations": CF_LABELS,
    "managers": strings(default=[]),
    "developers": strings(default=[]),
    "member_origin": field(description="Origin for simple managers/developers; rejected for DEV/project, whose legacy roles have individual origins."),
    "roles": mapping(CF_ROLE, default={}),
    "legacy_manager": dict(LEGACY_CF_ROLE, description="Only DEV/project, implemented by the existing root manager resource; rejected elsewhere."),
    "legacy_developer": dict(LEGACY_CF_ROLE, description="Only DEV/project, implemented by the existing root developer resource; rejected elsewhere."),
})
ALERT = obj({
    "enabled": field("bool", default=False),
    "plan": field(default="standard"),
    "instance": field("bool", default=True),
    "amount": ENTITLEMENT["properties"]["amount"],
    "plan_unique_identifier": field(),
    "instance_options": obj(INSTANCE_OPTIONS["properties"], default={}),
}, default={})
FLAGS = obj({
    **ALERT["properties"],
    "plan": field(default="lite"),
    "dashboard": field("bool", default=True),
    "dashboard_amount": ENTITLEMENT["properties"]["amount"],
    "dashboard_plan_unique_identifier": field(),
    "subscription_options": obj(SUBSCRIPTION_OPTIONS["properties"], default={}),
}, default={})
WORK_ZONE = obj({
    "enabled": field("bool", default=False),
    "plan": field(),
    "amount": ENTITLEMENT["properties"]["amount"],
    "plan_unique_identifier": field(),
    "subscription_options": obj(SUBSCRIPTION_OPTIONS["properties"], default={}),
}, default={})
SERVICES = obj({
    "alert_notification": ALERT, "feature_flags": FLAGS, "work_zone": WORK_ZONE,
    "entitlements": mapping(ENTITLEMENT, default={}),
    "instances": mapping(INSTANCE, default={}),
    "subscriptions": mapping(SUBSCRIPTION, default={}),
    "catalog": strings(default=[]),
    "catalog_amounts": mapping(ENTITLEMENT["properties"]["amount"], default={}),
}, default={})
CATALOG_ENTRY = obj({
    **ENTITLEMENT["properties"],
    "profiles": field("set",items=field(enum=["trial","enterprise"]), default=["trial", "enterprise"]),
    "instance": INSTANCE_OPTIONS,
    "subscription": obj({**SUBSCRIPTION_OPTIONS["properties"], "app_name": field()}),
})
ENVIRONMENT = obj({
    "enabled": field("bool", default=True),
    "name": field(minLength=1, maxLength=255, pattern=r"^[^/]+$"),
    "subdomain": field(pattern=r"^[a-z0-9]+(-[a-z0-9]+)*$"),
    "description": field(maxLength=300),
    "region": field(minLength=1, description="Actual region code, or null for an unambiguous catalog selection."),
    "iaas_provider": field(enum=["AWS", "AZURE", "GCP", "SAP", "ALI", "IBM"]),
    "runtime": field(default="cloudfoundry", description="btp_regions.environment predicate, not a subaccount API attribute."),
    "parent_id": field(format="uuid"),
    "usage": field(enum=["UNSET", "NOT_USED_FOR_PRODUCTION", "USED_FOR_PRODUCTION"]),
    "costcenter": field(required=True, pattern=r"^[0-9]{5}$"),
    "beta_enabled": field("bool", default=False),
    "skip_auto_entitlement": field("bool"),
    "labels": BTP_LABELS,
    "administrators_source": field(default="yaml", enum=["yaml", "legacy"]),
    "administrators": strings(default=[]),
    "administrator_options": obj({
        "role_collection_name": field(default="Subaccount Administrator", minLength=1),
        "origin": field(minLength=1),
    }, default={}),
    "role_assignments": mapping(BTP_ROLE, default={}),
    "cloud_foundry": obj({
        "enabled": field("bool", default=False),
        "name": field(),
        "plan": field(default="trial"),
        "environment_type": field(default="cloudfoundry"),
        "service_name": field(default="cloudfoundry"),
        "landscape_label": field(default=""),
        "parameters": field(description="Non-secret JSON; default preserves instance_name.", json_object=True),
        "parameters_key": field(description="Key into sensitive runtime environment_parameters."),
        "timeouts": TIMEOUTS,
        "spaces": mapping(SPACE, default={}),
    }, default={}),
    "services": SERVICES,
})
CONFIGURATION = obj({
    "schema_version": field("number", required=True, enum=[1, 2], integer=True),
    "account_type": field(required=True, enum=["trial", "enterprise"]),
    "project_name": field(required=True, pattern=r"^[A-Za-z0-9][A-Za-z0-9 -]*$"),
    "service_catalog": mapping(CATALOG_ENTRY, default={}),
    "environments": mapping(ENVIRONMENT, required=True),
}, required=True)


def hcl_type(node):
    kind = node["kind"]
    if kind == "object":
        fields = []
        for key, child in node["properties"].items():
            value = hcl_type(child)
            if not child["required"]:
                default = "" if child["default"] is None else ", " + json.dumps(child["default"])
                value = "optional(" + value + default + ")"
            fields.append(key + " = " + value)
        return "object({\n" + "\n".join(fields) + "\n})"
    if kind in ["map", "set"]:
        return kind + "(" + hcl_type(node["items"]) + ")"
    return kind


def json_schema(node):
    kind = node["kind"]
    types = {"string": "string", "bool": "boolean", "number": "number", "object": "object", "map": "object", "set": "array"}
    result = {"type": types[kind]}
    if node.get("integer"):
        result["type"] = "integer"
    for key in ["enum", "pattern", "format", "minimum", "maximum", "minLength", "maxLength", "maxProperties"]:
        if key in node:
            result[key] = node[key]
    if node["description"]:
        result["description"] = node["description"]
    if kind == "object":
        result.update(properties={k: json_schema(v) for k, v in node["properties"].items()}, additionalProperties=False)
        required = [k for k, v in node["properties"].items() if v["required"]]
        if required:
            result["required"] = required
        props = node["properties"]
        if "user" in props and "username" in props:
            result["oneOf"] = [
                {"required":["user"],"properties":{"user":{"type":"string"},"username":{"type":"null"},"origin":{"type":"null"}}},
                {"required":["username"],"properties":{"username":{"type":"string"},"user":{"type":"null"}}},
            ]
        if "user_name" in props and "group_name" in props and "attribute_name" in props:
            result["oneOf"] = [
                {"required":["user_name"],"properties":{"user_name":{"type":"string"},"group_name":{"type":"null"},"attribute_name":{"type":"null"},"attribute_value":{"type":"null"}}},
                {"required":["group_name","origin"],"properties":{"group_name":{"type":"string"},"origin":{"type":"string"},"user_name":{"type":"null"},"attribute_name":{"type":"null"},"attribute_value":{"type":"null"}}},
                {"required":["attribute_name","attribute_value","origin"],"properties":{"attribute_name":{"type":"string"},"attribute_value":{"type":"string"},"origin":{"type":"string"},"user_name":{"type":"null"},"group_name":{"type":"null"}}},
            ]
        if "parameters" in props and "parameters_key" in props:
            result["not"] = {"required":["parameters","parameters_key"],"properties":{"parameters":{"type":"string"},"parameters_key":{"type":"string"}}}
    elif kind == "map":
        result["additionalProperties"] = json_schema(dict(node["items"], required=True))
    elif kind == "set":
        result.update(items=json_schema(dict(node["items"], required=True)), uniqueItems=True)
    if not node["required"]:
        result = {"anyOf": [result, {"type": "null"}], "default": node["default"]}
    return result
