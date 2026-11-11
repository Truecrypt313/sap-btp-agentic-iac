"""Project identity, isolation, directories, service scope and deterministic builds."""
from copy import deepcopy
from pathlib import Path
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
import yaml
from build_landing_zone_config import ConfigurationError, ROOT, load_mapping
from project_configuration import assemble_project, build_projects, collect_projects, project_schema, validate_project
from jsonschema import Draft202012Validator


class ProjectTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        shutil.copytree(ROOT / "BTP/config", self.root / "BTP/config")
        self.directory = self.root / "BTP/config/projects/test-neu"

    def mutate(self, path, change):
        path = self.directory / path
        document = load_mapping(path)
        change(document)
        path.write_text(yaml.safe_dump(document))

    def second_project(self):
        target = self.directory.parent / "second-project"
        shutil.copytree(self.directory, target)
        path = target / "project.yaml"
        document = load_mapping(path)
        document.update(project_id="second-project", project_name="Second Project")
        path.write_text(yaml.safe_dump(document))
        path = target / "directory.yaml"
        document = load_mapping(path)
        document["directory"]["name"] = "Second Project Directory"
        path.write_text(yaml.safe_dump(document))
        return target

    def test_multiple_projects_have_independent_identity_and_outputs(self):
        self.second_project()
        projects = collect_projects(self.root)
        self.assertEqual(set(projects), {"test-neu", "second-project"})
        for project_id, project in projects.items():
            for stage, env in project["configuration"]["environments"].items():
                self.assertEqual(env["subdomain"], project_id + "-" + stage.lower())
                self.assertEqual(env["cloud_foundry"]["name"], env["subdomain"])
                self.assertNotIn("parent_id", env)
        build_projects(self.root)
        build_projects(self.root, check=True)
        self.assertTrue((self.root / "BTP/generated/second-project/landing-zone.yaml").exists())

    def test_legacy_artifact_byte_identical_and_directory_activation(self):
        build_projects(self.root)
        self.assertEqual((self.root / "BTP/landing-zone.yaml").read_bytes(), (ROOT / "BTP/landing-zone.yaml").read_bytes())
        project = collect_projects(self.root)["test-neu"]
        self.assertTrue(project["deployment_enabled"])
        self.assertTrue(project["directory"]["enabled"])
        for env in project["configuration"]["environments"].values():
            self.assertFalse(env["enabled"])
            self.assertFalse(env["cloud_foundry"]["enabled"])
            self.assertEqual(env["services"], {"catalog": []})
        self.assertIs(project["configuration"]["environments"]["DEV"]["skip_auto_entitlement"], True)

    def test_project_id_path_reserved_and_type_guards(self):
        path = self.directory / "project.yaml"
        original = path.read_bytes()
        for identity in ["project-abc", "../test-neu", "Test_Neu", "a"*41, "another", 42]:
            with self.subTest(identity=identity):
                path.write_bytes(original)
                self.mutate("project.yaml", lambda d: d.update(project_id=identity))
                with self.assertRaises(ConfigurationError):
                    collect_projects(self.root)

    def test_wrong_metadata_types_and_missing_fields(self):
        for key, value in [("deployment_enabled", "false"), ("account_type", "free"), ("schema_version", True), ("project_name", 42)]:
            path = self.directory / "project.yaml"
            original = path.read_bytes()
            with self.subTest(key=key):
                self.mutate("project.yaml", lambda d: d.update({key: value}))
                with self.assertRaises(ConfigurationError):
                    collect_projects(self.root)
                path.write_bytes(original)
        self.mutate("project.yaml", lambda d: d.pop("deployment_enabled"))
        with self.assertRaises(ConfigurationError):
            collect_projects(self.root)

    def test_all_directory_feature_combinations(self):
        project = assemble_project(self.root, self.directory)
        for features, valid in [(["DEFAULT"], True), (["DEFAULT","ENTITLEMENTS"],True), (["DEFAULT","ENTITLEMENTS","AUTHORIZATIONS"],True), (["DEFAULT","AUTHORIZATIONS"],False), (["ENTITLEMENTS"],False), ([],False), (["DEFAULT","OTHER"],False), (["DEFAULT","DEFAULT"],False)]:
            with self.subTest(features=features):
                project["directory"]["features"] = features
                self.assertEqual(not validate_project(project), valid)

    def test_subaccount_parent_and_legacy_iam_rejected(self):
        project = assemble_project(self.root, self.directory)
        for key, value in [("parent_id", "11111111-1111-4111-8111-111111111111"), ("administrators_source", "legacy"), ("subdomain", "other-project-dev")]:
            with self.subTest(key=key):
                copy = deepcopy(project)
                copy["configuration"]["environments"]["DEV"][key] = value
                self.assertTrue(validate_project(copy))

    def test_stage_and_cf_routing_is_project_scoped(self):
        project = assemble_project(self.root, self.directory)
        for stage in ["DEV", "TEST", "PROD"]:
            copy = deepcopy(project)
            copy["configuration"]["environments"][stage]["cloud_foundry"]["name"] = "foreign-org"
            self.assertTrue(validate_project(copy))
        self.mutate("environments/dev.yaml", lambda d: d.update(QA={}))
        with self.assertRaises(ConfigurationError):
            collect_projects(self.root)

    def test_trial_and_enterprise_prod(self):
        project = assemble_project(self.root, self.directory)
        project["configuration"]["environments"]["PROD"]["enabled"] = True
        self.assertTrue(validate_project(project))
        project["configuration"]["account_type"] = "enterprise"
        self.assertFalse(validate_project(project))

    def test_central_service_definitions_and_independent_activation(self):
        self.second_project()
        self.mutate("environments/dev.yaml", lambda d: d["DEV"]["services"].update(catalog=["alert_standard"]))
        projects = collect_projects(self.root)
        self.assertEqual(projects["test-neu"]["configuration"]["service_catalog"], projects["second-project"]["configuration"]["service_catalog"])
        self.assertEqual(projects["second-project"]["configuration"]["environments"]["DEV"]["services"]["catalog"], [])
        self.mutate("environments/test.yaml", lambda d: d["TEST"]["services"].update(catalog=["missing"]))
        with self.assertRaises(ConfigurationError):
            collect_projects(self.root)

    def test_directory_and_subaccount_name_collisions(self):
        target = self.second_project()
        path = target / "directory.yaml"
        original = path.read_bytes()
        document = load_mapping(path)
        document["directory"]["name"] = "Test_Neu"
        path.write_text(yaml.safe_dump(document))
        with self.assertRaises(ConfigurationError):
            collect_projects(self.root)
        path.write_bytes(original)
        path = target / "environments/dev.yaml"
        document = load_mapping(path)
        document["DEV"]["name"] = "Test Neu DEV"
        path.write_text(yaml.safe_dump(document))
        with self.assertRaises(ConfigurationError):
            collect_projects(self.root)

    def test_cross_project_service_instance_name_rejected(self):
        self.mutate("environments/dev.yaml", lambda d: d["DEV"]["services"].update(instances={
            "app": {"name":"foreign-dev-app", "offering":"feature-flags", "plan":"lite"},
        }))
        with self.assertRaises(ConfigurationError):
            collect_projects(self.root)

    def test_iam_isolation_and_policies_inactive(self):
        self.second_project()
        self.mutate("environments/dev.yaml", lambda d: d["DEV"].update(role_collections={
            "reader": {"name":"Test Neu Reader", "roles":{"reader":{"name":"Read","role_template_name":"Read","role_template_app_id":"app!test"}}},
        }))
        (self.directory / "iam/policies.yaml").write_text("intentionally invalid: [\n")
        projects = collect_projects(self.root)
        self.assertIn("reader", projects["test-neu"]["configuration"]["environments"]["DEV"]["role_collections"])
        self.assertEqual(projects["second-project"]["configuration"]["environments"]["DEV"]["role_collections"], {})
        self.assertNotIn("policies", projects["test-neu"])

    def test_individual_build_deterministic_and_does_not_touch_legacy(self):
        legacy = self.root / "BTP/landing-zone.yaml"
        legacy.write_bytes(b"unchanged sentinel")
        build_projects(self.root, project_id="test-neu")
        path = self.root / "BTP/generated/test-neu/landing-zone.yaml"
        before = path.read_bytes()
        build_projects(self.root, project_id="test-neu", check=True)
        build_projects(self.root, project_id="test-neu")
        self.assertEqual(before,path.read_bytes())
        self.assertEqual(legacy.read_bytes(),b"unchanged sentinel")

    def test_all_projects_validated_before_any_write(self):
        self.second_project()
        self.mutate("project.yaml", lambda d: d.update(deployment_enabled="invalid"))
        with self.assertRaises(ConfigurationError):
            build_projects(self.root)
        self.assertFalse((self.root / "BTP/landing-zone.yaml").exists())

    def test_missing_stale_and_orphan_generated_artifacts(self):
        with self.assertRaises(ConfigurationError):
            build_projects(self.root, check=True)
        build_projects(self.root)
        path = self.root / "BTP/generated/test-neu/landing-zone.yaml"
        path.write_bytes(b"stale")
        with self.assertRaises(ConfigurationError):
            build_projects(self.root, check=True)
        (self.root / "BTP/generated/orphan").mkdir()
        with self.assertRaises(ConfigurationError):
            build_projects(self.root)

    def test_project_schema_is_valid_and_current(self):
        Draft202012Validator.check_schema(project_schema())
        self.assertEqual(json.loads((ROOT / "schemas/project.schema.json").read_text()), project_schema())

    def test_mock_project_fixture_obeys_same_schema(self):
        document = load_mapping(ROOT / "examples/project.test-neu.mock.yaml")
        self.assertEqual(validate_project(document), [])

    def test_source_enabled_flags_required_and_not_defaulted(self):
        self.mutate("environments/dev.yaml", lambda d: d["DEV"].pop("enabled"))
        with self.assertRaises(ConfigurationError):
            collect_projects(self.root)

    def test_cli_unknown_project_has_safe_message_without_traceback(self):
        result = subprocess.run([sys.executable, str(ROOT / "scripts/build_landing_zone_config.py"), "--project", "unknown-project"], text=True, capture_output=True)
        self.assertEqual(result.returncode, 1)
        self.assertIn("Unbekannte Projekt-ID", result.stderr)
        self.assertNotIn("Traceback", result.stderr)

    def test_unused_catalog_definition_does_not_activate_or_reserve_instance(self):
        catalog = self.root / "BTP/config/service-catalog.yaml"
        doc = load_mapping(catalog)
        doc["service_catalog"]["future_definition"] = {
            "service_name": "future", "plan_name": "standard", "instance": {"name": "legacy-only-name"},
        }
        catalog.write_text(yaml.safe_dump(doc))
        self.assertIn("test-neu", collect_projects(self.root))
        self.mutate("environments/dev.yaml", lambda d: d["DEV"]["services"].update(catalog=["future_definition"]))
        with self.assertRaises(ConfigurationError):
            collect_projects(self.root)

    def test_source_and_output_symlinks_cannot_cross_project_boundaries(self):
        path = self.directory / "project.yaml"
        content = path.read_bytes()
        path.unlink()
        path.symlink_to(self.root / "BTP/config/project.yaml")
        with self.assertRaises(ConfigurationError):
            collect_projects(self.root)
        path.unlink()
        path.write_bytes(content)
        build_projects(self.root)
        artifact = self.root / "BTP/generated/test-neu/landing-zone.yaml"
        artifact.unlink()
        artifact.symlink_to(self.root / "BTP/landing-zone.yaml")
        with self.assertRaises(ConfigurationError):
            build_projects(self.root)


if __name__ == "__main__":
    unittest.main()
