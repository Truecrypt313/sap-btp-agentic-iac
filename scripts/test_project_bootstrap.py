"""Offline bootstrap, conflict, GitOps and rollback regressions."""
from copy import deepcopy
from pathlib import Path
from unittest.mock import patch
import json
import shutil
import tempfile
import subprocess
import unittest
import yaml

from build_landing_zone_config import ROOT, ConfigurationError, load_mapping
from project_bootstrap import prepare_project, prepare_pr
from bootstrap_configuration import ARTIFACT, build_registry, validate_request, profiles
from project_configuration import build_projects, collect_projects


def request(identity="alpha"):
    return {"schema_version": 1, "project_id": identity, "project_name": "Projekt " + identity,
            "directory_name": "Directory_" + identity, "account_profile": "trial", "environments": ["DEV", "TEST"],
            "cf_environments": ["DEV", "TEST"], "spaces": {"DEV": ["backend"], "TEST": ["testing"]}}


class ProjectBootstrapTests(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        for directory in ["BTP/config", "BTP/generated", "templates"]:
            shutil.copytree(ROOT / directory, self.root / directory)
        shutil.copyfile(ROOT / "BTP/landing-zone.yaml", self.root / "BTP/landing-zone.yaml")
        # This fixture deliberately exercises explicit registration of an existing project.
        (self.root / "BTP/config/projects/test-neu/bootstrap.yaml").unlink(missing_ok=True)
        (self.root / ".gitignore").write_text("/.project-bootstrap.lock\n")
        build_registry(self.root)
        self.before = self.snapshot()

    def snapshot(self):
        return {p.relative_to(self.root).as_posix(): p.read_bytes() for p in self.root.rglob("*") if p.is_file() and p.name != ".project-bootstrap.lock"}

    def test_create_generates_sources_and_artifacts_without_changing_existing_files(self):
        result = prepare_project(request(), self.root)
        self.assertEqual(result["status"], "created")
        for name, content in self.before.items():
            if name != str(ARTIFACT):
                self.assertEqual((self.root / name).read_bytes(), content, name)
        build_projects(self.root, check=True)
        self.assertEqual(build_registry(self.root, check=True)["projects"]["alpha"]["cf_environments"], ["DEV", "TEST"])
        cfg = collect_projects(self.root)["alpha"]
        self.assertFalse(cfg["deployment_enabled"])
        self.assertFalse(cfg["directory"]["enabled"])
        for stage, env in cfg["configuration"]["environments"].items():
            self.assertFalse(env["enabled"])
            self.assertEqual(env["cloud_foundry"]["enabled"], stage in ["DEV", "TEST"])
            self.assertTrue(env["skip_auto_entitlement"])
            self.assertEqual(env["services"], {"catalog": []})
            self.assertEqual(env["role_collections"], {})
        self.assertEqual(cfg["configuration"]["environments"]["DEV"]["cloud_foundry"]["spaces"], {"backend": {"name": "backend"}})
        self.assertEqual(cfg["configuration"]["service_catalog"], collect_projects(self.root)["test-neu"]["configuration"]["service_catalog"])

    def test_identical_order_independent_request_is_idempotent(self):
        prepare_project(request(), self.root)
        before = self.snapshot()
        retry = request()
        retry["environments"].reverse()
        retry["cf_environments"].reverse()
        self.assertEqual(prepare_project(retry, self.root)["status"], "unchanged")
        self.assertEqual(before, self.snapshot())

    def test_changed_request_never_overwrites_existing_project(self):
        prepare_project(request(), self.root)
        before = self.snapshot()
        changed = request()
        changed["project_name"] = "Other"
        with self.assertRaisesRegex(ConfigurationError, "keine Überschreibung"):
            prepare_project(changed, self.root)
        self.assertEqual(before, self.snapshot())

    def test_existing_unregistered_project_requires_explicit_registration(self):
        req = request("test-neu")
        req.update(project_name="Test Neu", directory_name="Test_Neu", spaces={"DEV": [], "TEST": []})
        with self.assertRaisesRegex(ConfigurationError, "register"):
            prepare_project(req, self.root)
        prepare_project(req, self.root, register_existing=True)
        for name, content in self.before.items():
            if name != str(ARTIFACT):
                self.assertEqual((self.root / name).read_bytes(), content, name)
        self.assertEqual(prepare_project(req, self.root, register_existing=True)["status"], "unchanged")

    def test_register_active_project_is_rejected(self):
        p = self.root / "BTP/config/projects/test-neu/project.yaml"
        document = load_mapping(p)
        document["deployment_enabled"] = True
        p.write_text(yaml.safe_dump(document))
        build_projects(self.root)
        req = request("test-neu")
        req.update(project_name="Test Neu", directory_name="Test_Neu")
        with self.assertRaisesRegex(ConfigurationError, "deaktivierte"):
            prepare_project(req, self.root, register_existing=True)

    def test_invalid_requests_trial_prod_and_secret_keys_are_rejected_without_writes(self):
        for field, value in [("project_id", "project-abc"), ("project_id", "../escape"), ("environments", ["PROD"]),
                             ("environments", ["DEV", "DEV"]), ("environments", "DEV"), ("account_profile", []),
                             ("account_profile", "enterprise"), ("project_name", "bad\nname"), ("directory_name", "bad/name"),
                             ("spaces", {"DEV": ["bad/name"], "TEST": []})]:
            bad = request()
            bad[field] = value
            with self.subTest(field=field, value=value), self.assertRaises(ConfigurationError):
                prepare_project(bad, self.root)
        bad = request()
        bad["token"] = "synthetic-private-value"
        with self.assertRaises(ConfigurationError):
            prepare_project(bad, self.root)
        self.assertEqual(self.before, self.snapshot())

    def test_cross_project_directory_conflict_is_detected_before_any_write(self):
        bad = request()
        bad["directory_name"] = "Test_Neu"
        with self.assertRaises(ConfigurationError):
            prepare_project(bad, self.root)
        self.assertEqual(self.before, self.snapshot())

    def test_stale_generated_registry_is_rejected(self):
        (self.root / ARTIFACT).write_text('{"schema_version":1,"projects":{"foreign":{}}}')
        with self.assertRaises(ConfigurationError):
            build_registry(self.root, check=True)

    def test_profile_rejects_invented_quotas_and_active_prod(self):
        p = self.root / "BTP/config/account-profiles.yaml"
        original = p.read_bytes()
        for key, value in [("max_subaccounts", 99), ("production_allowed", True), ("skip_auto_entitlement", False)]:
            d = yaml.safe_load(original)
            d["profiles"]["trial"][key] = value
            p.write_text(yaml.safe_dump(d))
            with self.subTest(key=key), self.assertRaises(ConfigurationError):
                profiles(self.root)

    def test_write_failure_rolls_back_new_project(self):
        from project_bootstrap import write_artifact
        calls = 0
        def failing(content, path, check):
            nonlocal calls
            calls += 1
            if calls == 2:
                raise OSError("synthetic failure")
            return write_artifact(content, path, check)
        with patch("project_bootstrap.write_artifact", side_effect=failing), self.assertRaises(ConfigurationError):
            prepare_project(request(), self.root)
        self.assertEqual(self.before, self.snapshot())

    def test_unowned_artifact_is_never_removed(self):
        p = self.root / "BTP/generated/alpha/landing-zone.yaml"
        p.parent.mkdir()
        p.write_text("synthetic unowned artifact")
        before = self.snapshot()
        with self.assertRaises(ConfigurationError):
            prepare_project(request(), self.root)
        self.assertEqual(before, self.snapshot())

    def test_concurrent_foreign_directory_is_not_deleted_during_rollback(self):
        target = self.root / "BTP/config/projects/alpha"
        mkdir = Path.mkdir
        def race(path, *args, **kwargs):
            if path == target:
                mkdir(path, *args, **kwargs)
                (path / "foreign.txt").write_text("Concurrent user work")
                raise FileExistsError("Concurrent user directory")
            return mkdir(path, *args, **kwargs)
        with patch.object(Path, "mkdir", race), self.assertRaises(ConfigurationError):
            prepare_project(request(), self.root)
        self.assertEqual((target / "foreign.txt").read_text(), "Concurrent user work")
        self.assertFalse((self.root / "BTP/generated/alpha").exists())

    def test_symlink_source_or_artifact_is_rejected(self):
        p = self.root / "HCP/generated/projects.json"
        content = p.read_bytes()
        p.unlink()
        outside = self.root / "outside"
        outside.write_bytes(content)
        p.symlink_to(outside)
        with self.assertRaises(ConfigurationError):
            prepare_project(request(), self.root)
        self.assertEqual(outside.read_bytes(), content)

    def test_gitops_refuses_unregistered_project(self):
        with patch("project_bootstrap.subprocess.run") as command, self.assertRaises(ConfigurationError):
            prepare_pr("project-abc", self.root)
        command.assert_not_called()

    def test_gitops_branch_commit_idempotency_and_foreign_changes(self):
        def git(*args):
            return subprocess.check_output(["git", *args], cwd=self.root, text=True, stderr=subprocess.DEVNULL).strip()
        git("init", "-b", "main")
        git("config", "user.name", "Bootstrap fixture")
        git("config", "user.email", "fixture@example.invalid")
        git("add", ".")
        git("commit", "-m", "Synthetic baseline")
        git("update-ref", "refs/remotes/origin/main", "HEAD")
        before = git("rev-parse", "HEAD")
        prepare_project(request(), self.root)
        foreign = self.root / "foreign.txt"
        foreign.write_text("unrelated user work")
        with self.assertRaisesRegex(ConfigurationError, "Fremde lokale"):
            prepare_pr("alpha", self.root)
        self.assertEqual(git("rev-parse", "HEAD"), before)
        self.assertEqual(foreign.read_text(), "unrelated user work")
        foreign.unlink()
        private = self.root / "BTP/config/projects/alpha/credentials.json"
        private.write_text('{"private": "synthetic"}')
        with self.assertRaisesRegex(ConfigurationError, "Secret-/Dateischutz"):
            prepare_pr("alpha", self.root)
        self.assertEqual(git("rev-parse", "HEAD"), before)
        private.unlink()
        result = prepare_pr("alpha", self.root)
        self.assertEqual(result["branch"], "bootstrap/alpha")
        self.assertEqual(prepare_pr("alpha", self.root), result)
        files = git("diff", "--name-only", before + "..HEAD").splitlines()
        self.assertTrue(all(p.startswith("BTP/config/projects/alpha/") or p in [str(ARTIFACT), "BTP/generated/alpha/landing-zone.yaml"] for p in files))


class BootstrapWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.workflow = yaml.load((ROOT / ".github/workflows/project-bootstrap.yml").read_text(), Loader=yaml.BaseLoader)

    def test_no_pr_execution_and_separate_main_dispatch_approval(self):
        events = self.workflow["on"]
        self.assertEqual(set(events), {"push", "workflow_dispatch"})
        self.assertEqual(events["push"]["branches"], ["main"])
        jobs = self.workflow["jobs"]
        self.assertIn("github.event_name == 'push'", jobs["plan-bootstrap"]["if"])
        self.assertIn("PROJECT_BOOTSTRAP_ENABLED == 'true'", jobs["plan-bootstrap"]["if"])
        self.assertIn("github.event_name == 'workflow_dispatch'", jobs["approve"]["if"])
        self.assertIn("github.ref == 'refs/heads/main'", jobs["approve"]["if"])
        self.assertIn("PROJECT_BOOTSTRAP_ENABLED == 'true'", jobs["approve"]["if"])
        self.assertEqual(jobs["approve"]["environment"], "hcp-${{ inputs.phase }}-apply")
        self.assertEqual(jobs["project-plans"]["environment"], "hcp-project-plan")
        self.assertEqual(jobs["project-plans"]["needs"], "approve")
        self.assertFalse(any("bootstrap_runs.py approve" in s.get("run", "") for s in jobs["plan-bootstrap"]["steps"]))

    def test_read_only_github_permissions_pinned_actions_and_safe_input_interpolation(self):
        self.assertEqual(self.workflow["permissions"], {"contents": "read"})
        import re
        for job in self.workflow["jobs"].values():
            for step in job["steps"]:
                if "uses" in step:
                    self.assertRegex(step["uses"], r"^[^@]+@[0-9a-f]{40}$")
                if step.get("uses", "").startswith("actions/checkout@"):
                    self.assertEqual(step["with"]["persist-credentials"], "false")
                self.assertNotIn("${{ inputs.", step.get("run", ""))
                self.assertNotIn("${{ secrets.", step.get("run", ""))

    def test_bootstrap_provider_block_is_identical_to_previously_pinned_tfe(self):
        from check_repository import lock_blocks
        old = lock_blocks((ROOT / "CloudFoundry/projects/.terraform.lock.hcl").read_text())
        current = lock_blocks((ROOT / "HCP/bootstrap/.terraform.lock.hcl").read_text())
        self.assertEqual(current, {"registry.terraform.io/hashicorp/tfe": old["registry.terraform.io/hashicorp/tfe"]})

    def test_hcp_free_bootstrap_has_no_team_or_custom_rbac_dependency(self):
        import re
        sources = "\n".join(p.read_text() for p in (ROOT / "HCP").rglob("*.tf"))
        self.assertEqual(set(re.findall(r'resource "([^"]+)"', sources)), {
            "tfe_workspace", "tfe_workspace_settings", "tfe_variable", "tfe_workspace_variable_set",
        })
        for removed in ["operator_teams", "directory_reader_team_id", "output_reader_team_id", "tfe_team_access"]:
            self.assertNotIn(removed, sources)

    def test_cf_handoff_still_reads_only_outputs_with_user_token_provider(self):
        source = (ROOT / "CloudFoundry/projects/main.tf").read_text()
        self.assertIn('data "tfe_outputs" "project"', source)
        self.assertIn("nonsensitive_values.project_contract", source)
        self.assertNotIn("terraform_remote_state", source)
        self.assertIn('provider "tfe" {}', source)  # TFE_TOKEN from the attached sensitive set.

    def test_existing_protected_environment_names_and_secret_route_are_preserved(self):
        jobs = self.workflow["jobs"]
        self.assertEqual(jobs["plan-bootstrap"]["environment"], "hcp-bootstrap-plan")
        self.assertEqual(jobs["project-plans"]["environment"], "hcp-project-plan")
        self.assertEqual(jobs["approve"]["environment"], "hcp-${{ inputs.phase }}-apply")
        self.assertEqual(self.workflow["on"]["workflow_dispatch"]["inputs"]["phase"]["options"], ["bootstrap", "core", "cf"])
        for name in ["plan-bootstrap", "project-plans", "approve"]:
            self.assertTrue(any(step.get("env", {}).get("HCP_ORCHESTRATION_TOKEN") == "${{ secrets.HCP_ORCHESTRATION_TOKEN }}" for step in jobs[name]["steps"]))


if __name__ == "__main__":
    unittest.main()
