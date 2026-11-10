#!/usr/bin/env python3
"""Offline configuration checks; public provider installation is the only network use.

Never invokes a real plan/apply/destroy. Terraform tests use mock providers
(or provider-free modules), and do not use HCP backends. Directory lifecycle
regressions also exercise apply/plan against mocks in disposable local state.
"""
from pathlib import Path
import argparse
import os
import shutil
import subprocess
import tempfile
import sys
import re
import json
import yaml

ROOT = Path(__file__).resolve().parents[1]
ROOTS = [
    ("BTP", True),
    ("CloudFoundry", True),
    ("CloudFoundry/environments", True),
    ("BTP/modules/landing-zone-config", True),
    ("BTP/modules/region-rules", True),
    ("BTP/modules/service-catalog-rules", True),
    ("BTP/modules/environment-services", True),
    ("BTP/modules/service-selection", True),
    ("BTP/modules/service-plan-rules", True),
    ("BTP/modules/srvc-baseline", True),
    ("BTP/modules/role-assignments", True),
    ("BTP/modules/role-collections", True),
    ("BTP/modules/role-catalog-rules", True),
    ("CloudFoundry/modules/spaces", True),
    ("BTP/modules/project-config", True),
    ("BTP/modules/directory", True),
    ("BTP/modules/directory-rules", True),
    ("BTP/modules/service-catalog", True),
    ("BTP/projects", True),
    ("CloudFoundry/projects", True),
    ("HCP/modules/project-workspaces", True),
    ("HCP/bootstrap", True),
]


def run(command, cwd, env, label):
    print(f"{label}: {' '.join(command)}", flush=True)
    subprocess.run(command, cwd=cwd, env=env, check=True)


def mock_plans(cwd, env, test_directory=None):
    command = ["terraform", "test", "-json", "-verbose"]
    if test_directory:
        command.append("-test-directory=" + test_directory)
    result = subprocess.run(command, cwd=cwd, env=env,
                            capture_output=True, text=True)
    records = [json.loads(line) for line in result.stdout.splitlines() if line.strip()]
    for record in records:
        if record["type"] not in ["test_plan", "test_state"] and (record["type"] != "diagnostic" or result.returncode):
            print(record.get("@message", ""), flush=True)
            if result.returncode and "diagnostic" in record:
                print(record["diagnostic"].get("detail", ""), flush=True)
    if result.returncode:
        raise SystemExit("Checked mock-plan tests failed: " + result.stderr)
    plans = {record["@testrun"]: record["test_plan"] for record in records if record["type"] == "test_plan"}
    return plans


def checked_bootstrap_plans(cwd, env):
    plans = mock_plans(cwd, env)
    repeated = plans["repeat_bootstrap_in_same_mock_state"]
    managed = [change for change in repeated.get("resource_changes", []) if change["mode"] == "managed"]
    if len(managed) != 15 or any(change["change"]["actions"] != ["no-op"] for change in managed):
        raise SystemExit("Repeated bootstrap must preserve all 15 managed mock objects with no-op actions")
    if any(change["actions"] != ["no-op"] for change in repeated.get("output_changes", {}).values()):
        raise SystemExit("Repeated bootstrap must not change output identities")
    print("Bootstrap mock plan verified: all 15 objects and outputs no-op; no duplicate workspaces.", flush=True)


def checked_mock_plans(cwd, env, test_directory=None):
    """Inspect real mock-plan actions, rather than asserting only equal outputs."""
    plans = mock_plans(cwd, env, test_directory)
    def changes(name):
        return [(item["address"], item["change"]["actions"]) for item in plans[name].get("resource_changes", []) if item["mode"] == "managed"]
    if test_directory:
        expected = [('btp_subaccount.environment["DEV"]', ["create"]), ('module.directory.btp_directory.this["project"]', ["create"])]
        if changes("minimal_dev_skips_auto_entitlements_and_requests_no_explicit_services") != expected:
            raise SystemExit("Minimal plan must create exactly one directory and DEV subaccount; no entitlement, CF or IAM resources")
        print("Minimal mock plan verified: exactly Directory + DEV Subaccount; no quota/CF/IAM resources.", flush=True)
        return
    if changes("repeat_plan_uses_owned_id_without_cycle") != [('btp_directory.this["project"]', ["no-op"])]:
        raise SystemExit("Repeat directory plan must contain exactly the owned directory with no-op actions")
    if any(change["actions"] != ["no-op"] for change in plans["repeat_plan_uses_owned_id_without_cycle"].get("output_changes", {}).values()):
        raise SystemExit("Repeat directory plan must not change any outputs")
    if changes("repeat_plan_with_metadata_change_keeps_identity") != [('btp_directory.this["project"]', ["update"])]:
        raise SystemExit("Directory metadata plan must show an update, without replacement or hidden drift")
    print("Directory mock plan actions verified: repeat = no-op; metadata = update; no replacement.", flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", nargs="+", choices=[root for root, _ in ROOTS], help="Check selected roots only.")
    selected = parser.parse_args().only
    run([sys.executable, "scripts/build_landing_zone_config.py", "--check"], ROOT, os.environ, ".")
    run([sys.executable, "scripts/build_project_schema.py"], ROOT, os.environ, ".")
    run([sys.executable, "scripts/project_bootstrap.py", "check"], ROOT, os.environ, ".")
    run([sys.executable, "scripts/check_state_addresses.py"], ROOT, os.environ, ".")
    run([sys.executable, "scripts/build_landing_zone_schema.py"], ROOT, os.environ, ".")
    run([sys.executable, "scripts/export_provider_schema.py", "--check"], ROOT, os.environ, ".")
    run([sys.executable, "scripts/validate_landing_zone.py"], ROOT, os.environ, ".")
    run([sys.executable, "-m", "unittest", "discover", "-s", "scripts", "-p", "test_*.py"], ROOT, os.environ, ".")
    run(["terraform", "fmt", "-check", "-recursive", "BTP", "CloudFoundry", "HCP"], ROOT, os.environ, ".")
    # Keep even empty local workspace directories and generated child-module
    # lock files out of the user's checkout. Never copy states or credentials.
    with tempfile.TemporaryDirectory(prefix="landing-zone-check-") as temporary:
        temporary = Path(temporary)
        checkout = temporary / "project"
        for directory in ["BTP", "CloudFoundry", "HCP", "examples", "scripts/fixtures"]:
            shutil.copytree(
                ROOT / directory,
                checkout / directory,
                ignore=shutil.ignore_patterns(
                    ".terraform", "terraform.tfstate*", "*.tfstate*", "*.tfvars*",
                    "*.tfplan*", ".env*", "*.secret", "*.secrets",
                ),
            )
        for relative, tests in ROOTS:
            if selected and relative not in selected:
                continue
            cwd = checkout / relative
            env = os.environ.copy()
            env.pop("TF_WORKSPACE", None)
            env.update(TF_DATA_DIR=str(temporary / "data" / relative), TF_INPUT="0", TF_IN_AUTOMATION="1")
            if relative == "CloudFoundry/environments":
                # Local mock tests exercise the same workspace routing guard
                # used by the intended remote TEST workspace.
                env["TF_WORKSPACE"] = "sap-cloudfoundry-test"
            if relative in ["BTP/projects", "CloudFoundry/projects"]:
                env["TF_WORKSPACE"] = "sap-btp-test-neu-" + ("core" if relative == "BTP/projects" else "cf-dev")
            if relative == "HCP/bootstrap":
                env["TF_WORKSPACE"] = "sap-btp-project-bootstrap"
            init = ["terraform", "init", "-backend=false", "-input=false", "-no-color"]
            if relative == "HCP/modules/project-workspaces":
                shutil.copyfile(ROOT / "HCP/bootstrap/.terraform.lock.hcl", cwd / ".terraform.lock.hcl")
                init.append("-lockfile=readonly")
            if relative in ["BTP/modules/environment-services", "BTP/modules/role-assignments", "BTP/modules/role-collections", "BTP/modules/srvc-baseline", "BTP/modules/directory", "BTP/modules/service-catalog", "CloudFoundry/modules/spaces"]:
                provider = "sap/btp" if relative.startswith("BTP/") else "cloudfoundry/cloudfoundry"
                parent = "BTP" if relative.startswith("BTP/") else "CloudFoundry"
                lock = (ROOT / parent / ".terraform.lock.hcl").read_text()
                block = re.search(r'provider "registry\.terraform\.io/' + provider + r'" \{.*?\n\}', lock, re.S)
                if not block:
                    raise SystemExit("Missing locked provider block for child-module test")
                (cwd / ".terraform.lock.hcl").write_text(block.group(0) + "\n")
                if relative == "BTP/modules/directory":
                    project_lock = (ROOT / "BTP/projects/.terraform.lock.hcl").read_text()
                    external_block = re.search(r'provider "registry\.terraform\.io/hashicorp/external" \{.*?\n\}', project_lock, re.S)
                    if not external_block:
                        raise SystemExit("Missing pinned directory preflight provider")
                    with (cwd / ".terraform.lock.hcl").open("a") as stream:
                        stream.write(external_block.group(0) + "\n")
                init.append("-lockfile=readonly")
            elif "/modules/" not in relative:
                init.append("-lockfile=readonly")
            run(init, cwd, env, relative)
            run(["terraform", "validate", "-no-color"], cwd, env, relative)
            if tests:
                canonical = checkout / "BTP/landing-zone.yaml"
                original = canonical.read_bytes()
                project_canonical = checkout / "BTP/generated/test-neu/landing-zone.yaml"
                project_original = project_canonical.read_bytes()
                try:
                    if relative == "CloudFoundry/environments":
                        canonical.write_bytes((checkout / "examples/landing-zone.enterprise.yaml").read_bytes())
                    if relative == "BTP/modules/directory":
                        checked_mock_plans(cwd, env)
                    elif relative == "HCP/modules/project-workspaces":
                        checked_bootstrap_plans(cwd, env)
                    else:
                        run(["terraform", "test", "-no-color"], cwd, env, relative)
                    if relative == "BTP":
                        canonical.write_bytes((checkout / "examples/landing-zone.enterprise.yaml").read_bytes())
                        run(["terraform", "test", "-no-color", "-test-directory=tests/enterprise"], cwd, env, relative)
                    if relative in ["BTP/projects", "CloudFoundry/projects"]:
                        project_canonical.write_bytes((checkout / "examples/project.test-neu.mock.yaml").read_bytes())
                        run(["terraform", "test", "-no-color", "-test-directory=tests/active"], cwd, env, relative)
                    if relative == "BTP/projects":
                        minimal = yaml.safe_load(project_original)
                        minimal["deployment_enabled"] = True
                        minimal["directory"]["enabled"] = True
                        minimal["configuration"]["environments"]["DEV"]["enabled"] = True
                        project_canonical.write_text(json.dumps(minimal))  # JSON is valid YAML.
                        checked_mock_plans(cwd, env, "tests/minimal")
                finally:
                    canonical.write_bytes(original)
                    project_canonical.write_bytes(project_original)


if __name__ == "__main__":
    main()
