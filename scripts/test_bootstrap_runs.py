"""Synthetic HCP API only. Tests never create a real run/workspace or apply."""
from copy import deepcopy
from unittest.mock import patch
from urllib.error import HTTPError
import unittest

from build_landing_zone_config import ConfigurationError
import bootstrap_runs as runs

SHA = "1" * 40
NAME = "sap-btp-project-bootstrap"


class FakeHCP:
    def __init__(self):
        self.calls = []
        self.ws = {"id": "ws-synthetic", "attributes": {"name": NAME, "working-directory": "HCP/bootstrap", "auto-apply": False,
            "terraform-version": "1.15.5", "execution-mode": "remote", "vcs-repo": {"identifier": runs.REPO, "branch": "main"}},
            "relationships": {"organization": {"data": {"id": runs.ORG}}, "current-configuration-version": {"data": {"id": "cv-synthetic"}}}}
        self.ingress = {"commit-sha": SHA, "branch": "main", "is-pull-request": False}
        self.run = {"id": "run-reviewed", "attributes": {"is-destroy": False, "refresh": True, "plan-only": False, "auto-apply": False,
                    "actions": {"is-confirmable": True}, "status": "planned", "has-changes": True},
                    "relationships": {"workspace": {"data": {"id": "ws-synthetic"}}, "plan": {"data": {"id": "plan-synthetic"}},
                                      "configuration-version": {"data": {"id": "cv-synthetic"}}}}
        self.metadata = {"status": "finished", "resource-destructions": 0, "resource-imports": 0, "action-invocations": 0}
        self.drift = False

    def call(self, method, path, payload=None):
        self.calls.append((method, path, deepcopy(payload)))
        if method == "POST" and path.endswith("/actions/apply"):
            self.run["attributes"]["status"] = "applied"
            return {}
        if method == "POST" and path == "/runs":
            return {"data": {"id": "run-drift"}}
        if "/organizations/" in path:
            return {"data": self.ws}
        if path.endswith("/ingress-attributes"):
            return {"data": {"attributes": self.ingress}}
        if path == "/runs/run-drift":
            return {"data": {"attributes": {"status": "planned_and_finished", "has-changes": self.drift}}}
        if path.startswith("/runs/"):
            return {"data": self.run}
        if path.startswith("/plans/"):
            return {"data": {"attributes": self.metadata}}
        raise AssertionError("Unexpected mock API request")


class BootstrapRunTests(unittest.TestCase):
    def setUp(self):
        self.client = FakeHCP()

    def approve(self, approval=None):
        return runs.approve(self.client, "bootstrap", SHA, "run-reviewed", approval or f"apply:{NAME}:run-reviewed:{SHA}")

    def test_plan_pins_exact_main_version_and_defaults_plan_only(self):
        result = runs.plan(self.client, "bootstrap", SHA)
        self.assertTrue(result["plan_only"])
        posted = [c for c in self.client.calls if c[:2] == ("POST", "/runs")][0][2]["data"]
        self.assertEqual(posted["relationships"]["configuration-version"]["data"]["id"], "cv-synthetic")
        self.assertEqual(posted["attributes"]["auto-apply"], False)
        self.assertEqual(posted["attributes"]["is-destroy"], False)
        self.assertFalse(any(c[1].endswith("/apply") for c in self.client.calls))

    def test_normal_plan_still_never_auto_applies(self):
        runs.plan(self.client, "bootstrap", SHA, allow_apply=True)
        data = self.client.calls[-1][2]["data"]["attributes"]
        self.assertFalse(data["plan-only"])
        self.assertFalse(data["auto-apply"])

    def test_matching_active_vcs_run_is_reused_without_duplicate_queue(self):
        self.client.ws["relationships"]["current-run"] = {"data": {"id": "run-reviewed"}}
        result = runs.plan(self.client, "bootstrap", SHA, allow_apply=True)
        self.assertEqual(result["run_id"], "run-reviewed")
        self.assertTrue(result["reused"])
        self.assertFalse(any(c[0] == "POST" for c in self.client.calls))

    def test_foreign_version_or_overridden_active_run_is_not_reused(self):
        for key, value in [("variables", [{"key":"override"}]), ("status", "errored")]:
            self.client = FakeHCP()
            self.client.ws["relationships"]["current-run"] = {"data": {"id": "run-reviewed"}}
            self.client.run["attributes"][key] = value
            result = runs.plan(self.client, "bootstrap", SHA, allow_apply=True)
            self.assertFalse(result["reused"])
        self.client = FakeHCP()
        self.client.ws["relationships"]["current-run"] = {"data": {"id": "run-reviewed"}}
        self.client.run["relationships"]["configuration-version"]["data"]["id"] = "cv-foreign"
        self.assertFalse(runs.plan(self.client, "bootstrap", SHA, allow_apply=True)["reused"])

    def test_wrong_commit_branch_or_pr_version_rejected_before_post(self):
        for key, value in [("commit-sha", "2"*40), ("branch", "feature"), ("is-pull-request", True)]:
            self.client = FakeHCP()
            self.client.ingress[key] = value
            with self.subTest(key=key), self.assertRaises(ConfigurationError):
                runs.plan(self.client, "bootstrap", SHA)
            self.assertFalse(any(c[0] == "POST" for c in self.client.calls))

    def test_vcs_version_mismatch_fails_immediately_without_retry(self):
        self.client.ingress["commit-sha"] = "2" * 40
        with patch.object(runs.time, "sleep") as pause, self.assertRaises(ConfigurationError):
            runs.plan(self.client, "bootstrap", SHA)
        pause.assert_not_called()
        self.assertEqual(sum(path.endswith("/ingress-attributes") for _, path, _ in self.client.calls), 1)
        self.assertFalse(any(method == "POST" for method, _, _ in self.client.calls))

    def test_wrong_workspace_settings_rejected(self):
        for key, value in [("name", "sap-btp-core"), ("auto-apply", True), ("working-directory", "BTP"), ("execution-mode", "local")]:
            self.client = FakeHCP()
            self.client.ws["attributes"][key] = value
            with self.subTest(key=key), self.assertRaises(ConfigurationError):
                runs.plan(self.client, "bootstrap", SHA)

    def test_explicit_approval_runs_apply_then_requires_clean_drift(self):
        result = self.approve()
        self.assertFalse(result["drift"])
        self.assertEqual(result["applied_run"], "run-reviewed")
        self.assertEqual(sum(c[0] == "POST" and c[1].endswith("/apply") for c in self.client.calls), 1)
        posted = [c for c in self.client.calls if c[:2] == ("POST", "/runs")][0][2]
        self.assertTrue(posted["data"]["attributes"]["plan-only"])

    def test_pr_approval_or_wrong_run_phrase_never_applies(self):
        with self.assertRaises(ConfigurationError):
            self.approve("approved PR")
        self.assertEqual(self.client.calls, [])

    def test_destroy_replace_import_action_and_speculative_run_cannot_be_approved(self):
        for key in ["resource-destructions", "resource-imports", "action-invocations"]:
            self.client = FakeHCP()
            self.client.metadata[key] = 1
            with self.subTest(key=key), self.assertRaises(ConfigurationError):
                self.approve()
            self.assertFalse(any(c[0] == "POST" for c in self.client.calls))
        self.client = FakeHCP()
        self.client.run["attributes"]["plan-only"] = True
        with self.assertRaises(ConfigurationError):
            self.approve()

    def test_targeted_replace_override_or_foreign_run_rejected(self):
        for key, value in [("target-addrs", ["resource.x"]), ("replace-addrs", ["resource.x"]), ("variables", [{"key":"override"}]), ("refresh-only", True), ("auto-apply", True)]:
            self.client = FakeHCP()
            self.client.run["attributes"][key] = value
            with self.subTest(key=key), self.assertRaises(ConfigurationError):
                self.approve()
        self.client = FakeHCP()
        self.client.run["relationships"]["workspace"]["data"]["id"] = "ws-foreign"
        with self.assertRaises(ConfigurationError):
            self.approve()

    def test_post_apply_drift_blocks_further_work(self):
        self.client.drift = True
        with self.assertRaisesRegex(ConfigurationError, "Drift"):
            self.approve()

    def test_post_apply_drift_uses_reviewed_version_even_after_new_merge(self):
        self.client.ws["relationships"]["current-configuration-version"]["data"]["id"] = "cv-newer"
        self.approve()
        posted = [c for c in self.client.calls if c[:2] == ("POST", "/runs")][0][2]
        self.assertEqual(posted["data"]["relationships"]["configuration-version"]["data"]["id"], "cv-synthetic")

    def test_sap_errors_are_actionable_without_log_excerpts(self):
        self.client.run["attributes"]["status"] = "errored"
        with self.assertRaisesRegex(ConfigurationError, "SAP-BTP.*Quoten"):
            runs.wait(self.client, "run-reviewed", {"applied"}, "core")

    def test_api_never_manages_workspaces_or_leaks_response_bodies(self):
        with patch.dict(runs.os.environ, {"HCP_ORCHESTRATION_TOKEN": "synthetic-private-token"}), patch.object(runs, "build_opener") as opener:
            client = runs.HCP()
            for method, path in [("POST", "/workspaces"), ("DELETE", "/workspaces/ws-foreign"), ("POST", "/state-versions")]:
                with self.subTest(method=method), self.assertRaises(ConfigurationError):
                    client.call(method, path, {})
            opener.assert_not_called()
            for code in [401, 403, 404, 409, 422, 500]:
                opener.return_value.open.side_effect = HTTPError("https://example.invalid/private-url", code, "private-body", {}, None)
                with self.assertRaises(ConfigurationError) as caught:
                    client.call("POST", "/runs", {})
                self.assertNotIn("private", str(caught.exception))

    def test_no_implicit_credentials(self):
        with patch.dict(runs.os.environ, {}, clear=True), self.assertRaises(ConfigurationError):
            runs.HCP()

    def test_foreign_workspace_with_same_name_is_not_owned_by_bootstrap_state(self):
        with patch.object(runs, "workspace", return_value={"id": "ws-bootstrap"}):
            with patch.object(self.client, "call", return_value={"data": [{"attributes": {
                "name": "project_workspace_ids", "sensitive": False, "value": {"alpha/core": "ws-owned"}
            }}]}):
                runs.verify_managed_workspace(self.client, {"id": "ws-owned"}, "core", "alpha", None)
                with self.assertRaisesRegex(ConfigurationError, "keine fremden"):
                    runs.verify_managed_workspace(self.client, {"id": "ws-foreign"}, "core", "alpha", None)


if __name__ == "__main__":
    unittest.main()
