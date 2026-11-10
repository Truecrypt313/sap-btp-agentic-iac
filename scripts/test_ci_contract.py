"""Regression tests for trigger coverage, CI permissions and file/lock safety."""
from pathlib import Path
import fnmatch
import json
import re
import tempfile
import unittest
import yaml
from check_repository import ROOT, check_locks, unsafe_file
from schema_model import CONFIGURATION, json_schema


def workflow_errors(document):
    errors = []
    events = document.get("on", {})
    if "pull_request" not in events or "pull_request_target" in events:
        errors.append("PR tests must use pull_request")
    for event in ["pull_request", "merge_group"]:
        if events.get(event):
            errors.append("No PR/merge path or branch filters allowed")
    if document.get("permissions") != {"contents": "read"}:
        errors.append("Only contents:read is permitted")
    for job in document.get("jobs", {}).values():
        if "if" in job or job.get("continue-on-error") or "paths" in job:
            errors.append("Checks must not be conditionally skipped")
        for step in job.get("steps", []):
            if "if" in step or step.get("continue-on-error"):
                errors.append("Required steps must not be skipped")
            if "uses" in step and not re.fullmatch(r"[^@]+@[0-9a-f]{40}", step["uses"]):
                errors.append("Pin actions to commit SHAs")
            if step.get("uses", "").startswith("actions/checkout@") and step.get("with", {}).get("persist-credentials") != "false":
                errors.append("Do not persist checkout credentials")
    return errors


def covered(patterns, name):
    return any(fnmatch.fnmatchcase("/" + name, pattern) for pattern in patterns)


class CIContractTests(unittest.TestCase):
    def setUp(self):
        self.workflow = yaml.load((ROOT / ".github/workflows/landing-zone-ci.yml").read_text(), Loader=yaml.BaseLoader)
        self.triggers = json.loads((ROOT / "schemas/hcp-vcs-triggers.json").read_text())

    def test_required_ci_no_filters_or_credentials(self):
        self.assertEqual(workflow_errors(self.workflow), [])
        source = (ROOT / ".github/workflows/landing-zone-ci.yml").read_text()
        self.assertNotIn("secrets.", source)
        for command in ["check_repository.py", "run_secret_scan.py", "check_landing_zone.py", "build_landing_zone_config.py --check", "export_provider_schema.py --refresh --check"]:
            self.assertIn(command, source)

    def test_reject_ci_path_filter_regression(self):
        self.workflow["on"]["pull_request"] = {"paths": ["BTP/**"]}
        self.assertTrue(workflow_errors(self.workflow))

    def test_reject_ci_write_permissions(self):
        self.workflow["permissions"] = {"contents": "write"}
        self.assertTrue(workflow_errors(self.workflow))

    def test_hcp_shared_dependency_paths(self):
        shared = ["BTP/landing-zone.yaml", "BTP/modules/landing-zone-config/main.tf", "schemas/landing-zone.schema.json", "scripts/build_landing_zone_schema.py"]
        for workspace, settings in self.triggers.items():
            self.assertTrue(settings["file-triggers-enabled"])
            self.assertEqual(settings["trigger-prefixes"], [])
            for name in shared:
                self.assertTrue(covered(settings["trigger-patterns"], name), (workspace, name))
        self.assertTrue(covered(self.triggers["sap-btp-core"]["trigger-patterns"], "BTP/modules/service-selection/main.tf"))
        self.assertTrue(covered(self.triggers["sap-cloudfoundry"]["trigger-patterns"], "CloudFoundry/modules/spaces/main.tf"))

    def test_hcp_paths_follow_actual_local_module_dependencies(self):
        for workspace, settings in self.triggers.items():
            seen = set()
            def visit(path):
                if path in seen:
                    return
                seen.add(path)
                for file in path.glob("*.tf"):
                    name = file.relative_to(ROOT).as_posix()
                    self.assertTrue(covered(settings["trigger-patterns"], name), (workspace, name))
                    for source in re.findall(r'source\s*=\s*"(\.[^\"]+)"', file.read_text()):
                        visit((path / source).resolve())
            visit(ROOT / settings["working-directory"])

    def test_reject_sensitive_artifacts(self):
        for name in ["BTP/terraform.tfstate", "CloudFoundry/pending.tfplan", "BTP/terraform.tfvars", ".env", "credentials.json", "id.key", "BTP/.terraform/cache", "scripts/__pycache__/cache.pyc"]:
            self.assertIsNotNone(unsafe_file(name, b"synthetic"), name)
        self.assertIsNotNone(unsafe_file("safe.txt", b"", symlink=True))
        self.assertIsNotNone(unsafe_file("safe.txt", b"\0"))

    def test_allow_source_schema_and_lock_files(self):
        for name in ["BTP/landing-zone.yaml", "BTP/.terraform.lock.hcl", "schemas/provider-resources.json", ".github/workflows/landing-zone-ci.yml"]:
            self.assertIsNone(unsafe_file(name, b"source"))

    def test_provider_upgrade_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            for name in ["BTP", "CloudFoundry", "CloudFoundry/environments"]:
                (root / name).mkdir(parents=True, exist_ok=True)
                content = (ROOT / name / ".terraform.lock.hcl").read_text()
                (root / name / ".terraform.lock.hcl").write_text(content)
            path = root / "BTP/.terraform.lock.hcl"
            path.write_text(path.read_text().replace('version     = "1.27.0"', 'version     = "1.28.0"'))
            with self.assertRaises(ValueError):
                check_locks(root, None)

    def test_every_schema_object_rejects_unknown_attributes(self):
        checked = 0
        def visit(node):
            nonlocal checked
            if node["kind"] == "object":
                checked += 1
                schema = json_schema(dict(node, required=True))
                self.assertIs(schema["additionalProperties"], False)
                for child in node["properties"].values():
                    visit(child)
            elif node["kind"] in ["map", "set"]:
                visit(node["items"])
        visit(CONFIGURATION)
        self.assertGreater(checked, 20)


if __name__ == "__main__":
    unittest.main()
