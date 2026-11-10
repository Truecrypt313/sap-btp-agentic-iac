"""Modular build failures, deterministic output and independent migration baseline."""
from pathlib import Path
import json
import shutil
import subprocess
import sys
import tempfile
import unittest
import yaml
from build_landing_zone_config import (
    ConfigurationError, HEADER, ROOT, assemble, build, load_mapping, render,
)
from schema_model import CONFIGURATION
from validate_landing_zone import normalize

FIXTURE = ROOT / "scripts/fixtures/landing-zone.pre-modular.json"


def canonical(value):
    # Unlike Python equality, distinguishes true/1 and null/missing.
    return json.dumps(value, sort_keys=True, ensure_ascii=False, allow_nan=False)


def terraform_sets(node, value):
    """Only canonicalize model-declared sets, preserving ordinary list order."""
    if value is None:
        return None
    if node["kind"] == "object":
        return {key: terraform_sets(child, value[key]) for key, child in node["properties"].items()}
    if node["kind"] == "map":
        return {key: terraform_sets(node["items"], child) for key, child in value.items()}
    if node["kind"] == "set":
        return sorted(value)
    return value


class BuildTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.config = self.root / "config"
        shutil.copytree(ROOT / "BTP/config", self.config)
        self.output = self.root / "landing-zone.yaml"

    def replace(self, name, mutate):
        path = self.config / name
        document = load_mapping(path)
        mutate(document)
        path.write_text(yaml.safe_dump(document), encoding="utf-8")

    def test_missing_each_required_source(self):
        for name in ["project.yaml", "service-catalog.yaml", *[f"environments/{s}.yaml" for s in ["dev", "test", "prod"]]]:
            with self.subTest(name=name):
                path = self.config / name
                original = path.read_bytes()
                path.unlink()
                with self.assertRaisesRegex(ConfigurationError, "fehlt"):
                    assemble(self.config)
                path.write_bytes(original)

    def test_yaml_syntax_is_redacted_and_does_not_overwrite(self):
        self.output.write_bytes(b"previous artifact")
        (self.config / "project.yaml").write_text("project_name: [DO_NOT_DISCLOSE\n")
        with self.assertRaises(ConfigurationError) as error:
            build(self.config, self.output)
        self.assertNotIn("DO_NOT_DISCLOSE", str(error.exception))
        self.assertEqual(self.output.read_bytes(), b"previous artifact")

    def test_missing_project_required_fields(self):
        for key in ["schema_version", "account_type", "project_name"]:
            with self.subTest(key=key):
                original = (self.config / "project.yaml").read_bytes()
                self.replace("project.yaml", lambda doc: doc.pop(key))
                with self.assertRaises(ConfigurationError):
                    assemble(self.config)
                (self.config / "project.yaml").write_bytes(original)

    def test_missing_nested_required_field(self):
        self.replace("environments/test.yaml", lambda doc: doc["TEST"].pop("costcenter"))
        with self.assertRaises(ConfigurationError):
            assemble(self.config)

    def test_wrong_types_are_not_coerced(self):
        mutations = [
            ("project.yaml", lambda d: d.update(schema_version=True)),
            ("project.yaml", lambda d: d.update(project_name=123)),
            ("environments/test.yaml", lambda d: d["TEST"].update(enabled="true")),
            ("environments/test.yaml", lambda d: d["TEST"].update(costcenter=12345)),
            ("environments/test.yaml", lambda d: d["TEST"].update(administrators={})),
            ("environments/test.yaml", lambda d: d["TEST"].update(role_assignments=[])),
            ("service-catalog.yaml", lambda d: d.update(service_catalog=[])),
        ]
        for name, mutate in mutations:
            with self.subTest(name=name, mutation=mutate):
                original = (self.config / name).read_bytes()
                self.replace(name, mutate)
                with self.assertRaises(ConfigurationError):
                    assemble(self.config)
                (self.config / name).write_bytes(original)

    def test_environment_wrappers_are_exact(self):
        path = self.config / "environments/test.yaml"
        original = load_mapping(path)
        for wrapper in ["test", "QA", "DEV"]:
            with self.subTest(wrapper=wrapper):
                path.write_text(yaml.safe_dump({wrapper: original["TEST"]}))
                with self.assertRaises(ConfigurationError):
                    assemble(self.config)
        path.write_text(yaml.safe_dump({**original, "PROD": original["TEST"]}))
        with self.assertRaises(ConfigurationError):
            assemble(self.config)

    def test_duplicate_keys_at_any_depth(self):
        path = self.config / "environments/test.yaml"
        for content in ["TEST: {}\nTEST: {}\n", "TEST:\n  enabled: true\n  enabled: false\n", "TEST:\n  role_assignments:\n    same: {}\n    same: {}\n"]:
            with self.subTest(content=content):
                path.write_text(content)
                with self.assertRaisesRegex(ConfigurationError, "Doppelter"):
                    assemble(self.config)

    def test_unexpected_environment_file(self):
        (self.config / "environments/qa.yaml").write_text("QA: {}\n")
        with self.assertRaises(ConfigurationError):
            assemble(self.config)

    def test_unknown_fields_do_not_enter_terraform_contract(self):
        self.replace("project.yaml", lambda d: d.update(policies={}))
        with self.assertRaises(ConfigurationError):
            assemble(self.config)
        self.replace("project.yaml", lambda d: d.pop("policies"))
        self.replace("environments/dev.yaml", lambda d: d["DEV"].update(unknown_field=True))
        with self.assertRaises(ConfigurationError):
            assemble(self.config)

    def test_inactive_policies_never_read_or_imported(self):
        before = render(assemble(self.config))
        path = self.config / "iam/policies.yaml"
        path.write_text("not even valid YAML: [\n")
        self.assertEqual(before, render(assemble(self.config)))
        path.unlink()
        self.assertEqual(before, render(assemble(self.config)))
        self.assertNotIn("policies", assemble(self.config))

    def test_trial_prod_remains_disabled(self):
        self.replace("environments/prod.yaml", lambda d: d["PROD"].update(enabled=True))
        with self.assertRaises(ConfigurationError):
            assemble(self.config)

    def test_invalid_iam_origin_rejected_by_existing_rules(self):
        self.replace("environments/test.yaml", lambda d: d["TEST"].update(role_assignments={
            "auditor": {"role_collection_key": "feature_flags_auditor", "user_name": "reader@example.invalid"},
        }))
        with self.assertRaises(ConfigurationError):
            assemble(self.config)

    def test_secret_parameters_redacted_and_no_artifact_written(self):
        self.replace("environments/test.yaml", lambda d: d["TEST"]["cloud_foundry"].update(
            parameters=json.dumps({"password": "DO_NOT_DISCLOSE"})))
        with self.assertRaises(ConfigurationError) as error:
            build(self.config, self.output)
        self.assertNotIn("DO_NOT_DISCLOSE", str(error.exception))
        self.assertFalse(self.output.exists())

    def test_yaml_only_types_non_string_keys_and_aliases_rejected(self):
        path = self.config / "project.yaml"
        for content in ["x: 2026-11-10\n", "x: .nan\n", "x: .inf\n", "1: value\n", "x: &x {y: 1}\nz: *x\n", "[]\n", "---\nx: 1\n---\nx: 2\n"]:
            with self.subTest(content=content):
                path.write_text(content)
                with self.assertRaises(ConfigurationError):
                    assemble(self.config)

    def test_deterministic_across_processes_and_source_map_order(self):
        expected = render(assemble(self.config))
        for path in self.config.rglob("*.yaml"):
            if "iam" not in path.parts:
                document = load_mapping(path)
                path.write_text(yaml.safe_dump(dict(reversed(list(document.items())))))
        build(self.config, self.output)
        self.assertEqual(expected, self.output.read_bytes())
        mtime = self.output.stat().st_mtime_ns
        build(self.config, self.output)
        self.assertEqual(mtime, self.output.stat().st_mtime_ns)
        source = "from build_landing_zone_config import *; import sys; sys.stdout.buffer.write(render(assemble(ROOT / 'BTP/config')))"
        for _ in range(2):
            result = subprocess.check_output([sys.executable, "-c", source], cwd=ROOT / "scripts")
            self.assertEqual(expected, result)

    def test_round_trip_preserves_all_value_types_and_lists(self):
        document = {"null": None, "bool": False, "int": 2, "float": 1.25,
                    "string": "12345", "list": ["z", "a", None, True, 3], "map": {"empty": {}}}
        self.assertEqual(canonical(document), canonical(yaml.safe_load(render(document))))

    def test_check_missing_stale_invalid_or_old_generation_never_writes(self):
        for content in [None, b"not YAML: [", b"# old generator\n", render(assemble(self.config)).replace(HEADER.encode(), b"")]:
            with self.subTest(content=content):
                self.output.unlink(missing_ok=True)
                if content is not None:
                    self.output.write_bytes(content)
                with self.assertRaises(ConfigurationError):
                    build(self.config, self.output, check=True)
                self.assertEqual(content, self.output.read_bytes() if self.output.exists() else None)

    def test_tracked_artifact_is_current(self):
        build(ROOT / "BTP/config", ROOT / "BTP/landing-zone.yaml", check=True)

    def test_raw_and_normalized_match_pre_refactor_snapshot(self):
        baseline = json.loads(FIXTURE.read_text())
        actual = assemble(self.config)
        self.assertEqual(canonical(actual), canonical(baseline["raw"]))
        normalized = terraform_sets(CONFIGURATION, normalize(CONFIGURATION, actual))
        self.assertEqual(canonical(normalized), canonical(baseline["normalized"]))
        # Preserve explicit null vs omitted, including the intentionally sparse TEST.
        self.assertIn("parameters", actual["environments"]["DEV"]["cloud_foundry"])
        self.assertNotIn("parameters", actual["environments"]["TEST"]["cloud_foundry"])

    def test_all_iam_and_legacy_values_match_snapshot(self):
        baseline = json.loads(FIXTURE.read_text())["normalized"]
        actual = normalize(CONFIGURATION, assemble(self.config))
        for stage in ["DEV", "TEST", "PROD"]:
            for key in ["administrators_source", "administrators", "administrator_options", "role_collections", "role_assignments"]:
                self.assertEqual(canonical(actual["environments"][stage][key]), canonical(baseline["environments"][stage][key]))
            self.assertEqual(canonical(actual["environments"][stage]["cloud_foundry"]["spaces"]),
                             canonical(baseline["environments"][stage]["cloud_foundry"]["spaces"]))


if __name__ == "__main__":
    unittest.main()
