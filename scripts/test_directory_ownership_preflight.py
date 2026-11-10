"""State/inventory security regressions. Only synthetic API/state fixtures."""
from copy import deepcopy
from io import StringIO
from unittest.mock import patch
from urllib.error import HTTPError
import json
import sys
import unittest

import directory_ownership_preflight as guard

OWN = "11111111-1111-4111-8111-111111111111"
FOREIGN = "22222222-2222-4222-8222-222222222222"
WORKSPACE = "sap-btp-test-neu-core"


def row(identity=OWN, name="Test_Neu", projects=None):
    return {"id": identity, "name": name, "project_ids": ["test-neu"] if projects is None else projects}


def state():
    return {"version": 4, "serial": 1, "lineage": "33333333-3333-4333-8333-333333333333",
            "outputs": {"project_contract": {"value": {"directory_id": FOREIGN}}},
            "resources": [{"mode": "managed", "module": "module.directory", "type": "btp_directory", "name": "this",
                           "provider": 'provider["registry.terraform.io/sap/btp"]',
                           "instances": [{"index_key": "project", "attributes": {"id": OWN, "name": "Old metadata"}}]}]}


class DirectoryOwnershipTests(unittest.TestCase):
    def setUp(self):
        self.query = {"project_id": "test-neu", "workspace": WORKSPACE, "name": "Test_Neu", "inventory": "[]"}
        self.environ = {"TFC_RUN_ID": "run-synthetic", "TFC_WORKSPACE_ID": "ws-synthetic",
                        "TFC_WORKSPACE_NAME": WORKSPACE, "DIRECTORY_PREFLIGHT_HCP_TOKEN": "synthetic-token"}
        self.ws = {"attributes": {"name": WORKSPACE, "working-directory": "BTP/projects", "execution-mode": "remote", "auto-apply": False},
                   "relationships": {"organization": {"data": {"id": guard.ORGANIZATION}}, "current-state-version": {"data": None}}}
        self.responses = {
            guard.API + "/runs/run-synthetic": {"data": {"attributes": {"refresh": True}, "relationships": {"workspace": {"data": {"id": "ws-synthetic"}}}}},
            guard.API + "/workspaces/ws-synthetic": {"data": self.ws}}
        self.calls = []

    def read(self, url, token=None):
        self.calls.append((url, token))
        return self.responses[url]

    def existing(self, snapshot=None):
        self.ws["relationships"]["current-state-version"]["data"] = {"id": "sv-synthetic"}
        self.responses[guard.API + "/workspaces/ws-synthetic/current-state-version"] = {
            "data": {"id": "sv-synthetic", "attributes": {"serial": 1, "hosted-state-download-url": "https://archivist.terraform.io/synthetic"}}}
        self.responses["https://archivist.terraform.io/synthetic"] = state() if snapshot is None else snapshot

    def check(self, inventory):
        self.query["inventory"] = json.dumps(inventory)
        return guard.preflight(self.query, self.environ, self.read)

    def test_first_creation_with_explicit_absent_state(self):
        self.assertEqual(self.check([])["managed_id"], "")
        self.assertEqual(len(self.calls), 2)

    def test_state_exists_without_directory_is_first_creation(self):
        snapshot = state()
        snapshot["resources"] = []
        self.existing(snapshot)
        self.assertEqual(self.check([])["managed_id"], "")

    def test_repeat_plan_accepts_actual_id_not_output_or_metadata(self):
        self.existing()
        result = self.check([row(), row(FOREIGN, "Other", [])])
        self.assertEqual(result["managed_id"], OWN)
        self.assertEqual(result["resource_address"], guard.ADDRESS)
        self.assertEqual(result["state_serial"], "1")
        self.assertIsNone(self.calls[-1][1])  # no bearer header to the download URL

    def test_owned_metadata_drift_or_intentional_rename_does_not_change_ownership(self):
        self.existing()
        self.assertEqual(self.check([row(name="Changed", projects=["changed"])])["managed_id"], OWN)
        self.query["name"] = "New requested name"
        self.assertEqual(self.check([row()])["managed_id"], OWN)

    def test_foreign_same_name_rejected_on_first_and_repeat_plan(self):
        for previous in [False, True]:
            with self.subTest(previous=previous):
                if previous:
                    self.existing()
                with self.assertRaisesRegex(guard.PreflightError, "Foreign directory"):
                    self.check(([row()] if previous else []) + [row(FOREIGN, "test_neu", [])])

    def test_foreign_same_project_rejected_on_first_and_repeat_plan(self):
        for previous in [False, True]:
            with self.subTest(previous=previous):
                if previous:
                    self.existing()
                with self.assertRaisesRegex(guard.PreflightError, "Foreign directory"):
                    self.check(([row()] if previous else []) + [row(FOREIGN, "Another name")])

    def test_never_adopt_inventory_without_state(self):
        with self.assertRaisesRegex(guard.PreflightError, "Foreign directory"):
            self.check([row()])

    def test_missing_owned_inventory_entry_blocks_automatic_recreation(self):
        self.existing()
        with self.assertRaisesRegex(guard.PreflightError, "absent from inventory"):
            self.check([])

    def test_duplicate_ids_and_malformed_inventory_rejected(self):
        self.existing()
        for inventory in [[row(), row()], [row(identity="invalid")], [row(projects="test-neu")], [dict(row(), unexpected="private")], {}]:
            with self.subTest(inventory=inventory), self.assertRaises(guard.PreflightError):
                self.check(inventory)

    def test_caller_cannot_supply_managed_identity(self):
        self.query["managed_id"] = OWN
        with self.assertRaisesRegex(guard.PreflightError, "caller-supplied ownership"):
            self.check([row()])

    def test_wrong_or_missing_runtime_context_rejected(self):
        original = deepcopy(self.environ)
        for field in original:
            for value in ["", "wrong"]:
                if field == "DIRECTORY_PREFLIGHT_HCP_TOKEN" and value == "wrong":
                    continue  # authentication failure covered at HTTP boundary
                with self.subTest(field=field, value=value), self.assertRaises(guard.PreflightError):
                    self.environ = dict(original, **{field: value})
                    self.check([])

    def test_foreign_workspace_settings_and_legacy_identity_rejected(self):
        for key, value in [("name", "sap-btp-core"), ("working-directory", "BTP"), ("auto-apply", True), ("execution-mode", "local")]:
            original = self.ws["attributes"][key]
            with self.subTest(key=key), self.assertRaises(guard.PreflightError):
                self.ws["attributes"][key] = value
                self.check([])
            self.ws["attributes"][key] = original
        self.query["project_id"] = "project-abc"
        with self.assertRaises(guard.PreflightError):
            self.check([])

    def test_wrong_org_or_missing_state_relationship_is_not_empty_state(self):
        self.ws["relationships"]["organization"]["data"]["id"] = "other"
        with self.assertRaises(guard.PreflightError):
            self.check([])
        self.ws["relationships"]["organization"]["data"]["id"] = guard.ORGANIZATION
        del self.ws["relationships"]["current-state-version"]
        with self.assertRaises(KeyError):
            self.check([])  # CLI converts malformed responses to a safe fatal error

    def test_refresh_disabled_is_rejected(self):
        self.responses[guard.API + "/runs/run-synthetic"]["data"]["attributes"]["refresh"] = False
        with self.assertRaisesRegex(guard.PreflightError, "refreshed plan"):
            self.check([])

    def test_changed_state_version_or_serial_is_rejected(self):
        self.existing()
        version = self.responses[guard.API + "/workspaces/ws-synthetic/current-state-version"]["data"]
        for key, value in [("id", "sv-changed"), ("attributes", {"serial": 2, "hosted-state-download-url": "https://archivist.terraform.io/synthetic"})]:
            original = deepcopy(version[key])
            with self.subTest(key=key), self.assertRaises(guard.PreflightError):
                version[key] = value
                self.check([row()])
            version[key] = original

    def test_tainted_deposed_wrong_address_provider_and_multiple_state_rejected(self):
        for change in [lambda r: r.update(module="module.foreign"), lambda r: r.update(provider='provider["other"]'),
                       lambda r: r["instances"][0].update(index_key="other"), lambda r: r["instances"][0].update(status="tainted"),
                       lambda r: r["instances"][0].update(deposed="old"), lambda r: r["instances"].append(deepcopy(r["instances"][0]))]:
            snapshot = state()
            change(snapshot["resources"][0])
            with self.subTest(change=change), self.assertRaises(guard.PreflightError):
                guard.managed_directory_id(snapshot)

    def test_http_errors_fail_closed_without_response_or_token(self):
        for code in [401, 403, 404, 500]:
            with patch.object(guard, "build_opener") as opener:
                opener.return_value.open.side_effect = HTTPError(guard.API + "/synthetic", code, "private-body", {}, None)
                with self.assertRaises(guard.PreflightError) as caught:
                    guard.read_json(guard.API + "/synthetic", token="synthetic-private-token")
                self.assertNotIn("private", str(caught.exception))

    def test_no_authentication_to_download_or_http_redirect(self):
        for url in ["http://app.terraform.io/state", "https://user:secret@example.invalid/state", "https://example.invalid/state"]:
            with self.subTest(url=url), self.assertRaises(guard.PreflightError):
                guard.read_json(url, token="synthetic-private-token")
        with self.assertRaises(guard.PreflightError):
            guard.NoRedirect().redirect_request(None, None, 302, None, None, "https://other.invalid")

    def test_cli_redacts_malformed_input_and_requires_credentials(self):
        for query in [{"project_id": "synthetic-private-input"}, self.query]:
            with patch.object(sys, "stdin", StringIO(json.dumps(query))), patch.object(sys, "stdout", StringIO()) as out, \
                    patch.object(sys, "stderr", StringIO()) as err, patch.dict(guard.os.environ, {}, clear=True):
                self.assertEqual(guard.main(), 1)
                self.assertEqual(out.getvalue(), "")
                self.assertNotIn("synthetic-private-input", err.getvalue())


if __name__ == "__main__":
    unittest.main()
