"""Tests of strict raw YAML validation, including fields Terraform would drop."""
from copy import deepcopy
from pathlib import Path
import unittest
import yaml
from validate_landing_zone import validate_document

ROOT = Path(__file__).resolve().parents[1]


class ConfigurationTests(unittest.TestCase):
    def setUp(self):
        self.config = yaml.safe_load((ROOT / "BTP/landing-zone.yaml").read_text())

    def reject(self, mutate):
        mutate(self.config)
        self.assertTrue(validate_document(self.config))

    def test_active_configuration(self):
        self.assertFalse(validate_document(self.config))

    def test_all_example_profiles(self):
        for path in (ROOT / "examples").glob("landing-zone.*.yaml"):
            self.assertFalse(validate_document(yaml.safe_load(path.read_text())), path.name)

    def test_unknown_attribute(self):
        self.reject(lambda c: c["environments"]["TEST"].update(descripton="typo"))

    def test_readonly_space_quota(self):
        self.reject(lambda c: c["environments"]["DEV"]["cloud_foundry"]["spaces"]["project"].update(quota="not writable"))

    def test_invalid_usage_enum(self):
        self.reject(lambda c: c["environments"]["TEST"].update(usage="production"))

    def test_numeric_costcenter(self):
        self.reject(lambda c: c["environments"]["TEST"].update(costcenter=12345))

    def test_description_limit(self):
        self.reject(lambda c: c["environments"]["TEST"].update(description="x" * 301))

    def test_invalid_parent_uuid(self):
        self.reject(lambda c: c["environments"]["TEST"].update(parent_id="not-a-uuid"))

    def test_ambiguous_role_subject(self):
        self.reject(lambda c: c["environments"]["TEST"]["role_assignments"].update(
            bad={"role_collection_name":"Viewer","user_name":"example","group_name":"group","origin":"idp"}))

    def test_attribute_role_requires_value_and_origin(self):
        self.reject(lambda c: c["environments"]["TEST"]["role_assignments"].update(
            bad={"role_collection_name":"Viewer","attribute_name":"department"}))

    def test_cf_guid_and_username_conflict(self):
        self.reject(lambda c: c["environments"]["DEV"]["cloud_foundry"]["spaces"]["project"]["roles"].update(
            bad={"type":"space_auditor","user":"11111111-1111-4111-8111-111111111111","username":"example"}))

    def test_numeric_quota_range(self):
        self.reject(lambda c: c["service_catalog"]["alert_standard"].update(amount=2000000001))

    def test_parameters_must_be_json_object(self):
        self.reject(lambda c: c["environments"]["DEV"]["services"]["alert_notification"].update(instance_options={"parameters":"[]"}))

    def test_secrets_are_references(self):
        self.reject(lambda c: c["environments"]["DEV"]["services"]["alert_notification"].update(instance_options={"parameters":'{"password":"not-a-real-secret"}'}))

    def test_invalid_timeout(self):
        self.reject(lambda c: c["environments"]["DEV"]["cloud_foundry"].update(timeouts={"create":"forever"}))

    def test_unknown_catalog_alias(self):
        self.reject(lambda c: c["environments"]["TEST"]["services"].update(catalog=["undefined"]))

    def test_trial_production(self):
        self.reject(lambda c: c["environments"]["PROD"].update(enabled=True))

    def test_plain_and_nested_secret_keys(self):
        import json
        for key in ["token", "secret", "api-key", "clientSecret", "private_key", "access_token"]:
            config = deepcopy(self.config)
            config["environments"]["DEV"]["cloud_foundry"]["parameters"] = json.dumps({"nested": [{key: "synthetic-placeholder"}]})
            self.assertTrue(validate_document(config), key)

    def test_legacy_options_scope(self):
        for stage, space_key in [("TEST", "project"), ("DEV", "other")]:
            config = deepcopy(self.config)
            config["environments"][stage]["cloud_foundry"].update(enabled=True, spaces={space_key: {"name": "space", "legacy_manager": {"username": "admin@example.invalid"}}})
            self.assertTrue(validate_document(config))

    def test_supported_dev_legacy_options(self):
        self.config["environments"]["DEV"]["cloud_foundry"]["spaces"]["project"]["legacy_manager"] = {"username": "admin@example.invalid", "origin": "idp"}
        self.assertFalse(validate_document(self.config))

    def test_dev_project_rejects_unused_member_origin(self):
        self.reject(lambda c: c["environments"]["DEV"]["cloud_foundry"]["spaces"]["project"].update(member_origin="idp"))

    def test_test_collections_are_least_privilege_and_unassigned(self):
        env = self.config["environments"]["TEST"]
        collections = env["role_collections"]
        self.assertEqual(set(collections), {"feature_flags_administrator", "feature_flags_auditor"})
        for key, suffix in [("feature_flags_administrator", "Administrator"), ("feature_flags_auditor", "Auditor")]:
            collection = collections[key]
            self.assertEqual(collection["name"], "TEST_FeatureFlags_" + suffix)
            self.assertEqual(list(collection["roles"].values()), [{
                "name": "Feature Flags Service dashboard " + suffix,
                "role_template_name": "FeatureFlags_Dashboard_" + suffix,
                "role_template_app_id": "feature-flags!b1765",
            }])
        self.assertEqual(env["role_assignments"], {})
        self.assertEqual(env["administrators"], [])
        for stage in ["DEV", "PROD"]:
            self.assertEqual(self.config["environments"][stage].get("role_collections", {}), {})

    def test_managed_assignment_requires_explicit_origin_and_valid_key(self):
        env = self.config["environments"]["TEST"]
        assignment = {"role_collection_key": "feature_flags_auditor", "user_name": "reader@example.invalid", "origin": "sap.default"}
        env["role_assignments"] = {"reader": assignment}
        self.assertFalse(validate_document(self.config))
        del assignment["origin"]
        self.assertTrue(validate_document(self.config))
        assignment.update(origin="sap.default", role_collection_key="missing")
        self.assertTrue(validate_document(self.config))

    def test_collection_selectors_are_exclusive(self):
        self.reject(lambda c: c["environments"]["TEST"]["role_assignments"].update(
            reader={"role_collection_name": "Existing", "role_collection_key": "feature_flags_auditor", "user_name": "reader", "origin": "sap.default"}))

    def test_managed_name_requires_key_to_preserve_dependency(self):
        self.reject(lambda c: c["environments"]["TEST"]["role_assignments"].update(
            reader={"role_collection_name": "TEST_FeatureFlags_Auditor", "user_name": "reader", "origin": "sap.default"}))

    def test_duplicate_collection_names(self):
        self.reject(lambda c: c["environments"]["TEST"]["role_collections"]["feature_flags_auditor"].update(name="TEST_FeatureFlags_Administrator"))

    def test_empty_collection_roles(self):
        self.reject(lambda c: c["environments"]["TEST"]["role_collections"]["feature_flags_auditor"].update(roles={}))

    def test_duplicate_roles_in_collection(self):
        collection = self.config["environments"]["TEST"]["role_collections"]["feature_flags_auditor"]
        collection["roles"]["duplicate"] = deepcopy(collection["roles"]["dashboard"])
        self.assertTrue(validate_document(self.config))

    def test_collection_requires_complete_role_identity(self):
        role = self.config["environments"]["TEST"]["role_collections"]["feature_flags_auditor"]["roles"]["dashboard"]
        del role["role_template_app_id"]
        self.assertTrue(validate_document(self.config))

    def test_generated_json_schema_is_valid(self):
        import json
        from jsonschema import Draft202012Validator
        Draft202012Validator.check_schema(json.loads((ROOT / "schemas/landing-zone.schema.json").read_text()))


if __name__ == "__main__":
    unittest.main()
