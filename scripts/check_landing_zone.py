#!/usr/bin/env python3
"""Offline configuration checks; public provider installation is the only network use.

Never invokes a real plan/apply/destroy. Terraform tests use command=plan with
mock providers (or a provider-free schema module), and do not use HCP backends.
"""
from pathlib import Path
import argparse
import os
import shutil
import subprocess
import tempfile
import sys
import re

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
]


def run(command, cwd, env, label):
    print(f"{label}: {' '.join(command)}", flush=True)
    subprocess.run(command, cwd=cwd, env=env, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", nargs="+", choices=[root for root, _ in ROOTS], help="Check selected roots only.")
    selected = parser.parse_args().only
    run([sys.executable, "scripts/build_landing_zone_config.py", "--check"], ROOT, os.environ, ".")
    run([sys.executable, "scripts/check_state_addresses.py"], ROOT, os.environ, ".")
    run([sys.executable, "scripts/build_landing_zone_schema.py"], ROOT, os.environ, ".")
    run([sys.executable, "scripts/export_provider_schema.py", "--check"], ROOT, os.environ, ".")
    run([sys.executable, "scripts/validate_landing_zone.py"], ROOT, os.environ, ".")
    run([sys.executable, "-m", "unittest", "discover", "-s", "scripts", "-p", "test_*.py"], ROOT, os.environ, ".")
    run(["terraform", "fmt", "-check", "-recursive", "BTP", "CloudFoundry"], ROOT, os.environ, ".")
    # Keep even empty local workspace directories and generated child-module
    # lock files out of the user's checkout. Never copy states or credentials.
    with tempfile.TemporaryDirectory(prefix="landing-zone-check-") as temporary:
        temporary = Path(temporary)
        checkout = temporary / "project"
        for directory in ["BTP", "CloudFoundry", "examples", "scripts/fixtures"]:
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
            init = ["terraform", "init", "-backend=false", "-input=false", "-no-color"]
            if relative in ["BTP/modules/environment-services", "BTP/modules/role-assignments", "BTP/modules/role-collections", "BTP/modules/srvc-baseline", "CloudFoundry/modules/spaces"]:
                provider = "sap/btp" if relative.startswith("BTP/") else "cloudfoundry/cloudfoundry"
                parent = "BTP" if relative.startswith("BTP/") else "CloudFoundry"
                lock = (ROOT / parent / ".terraform.lock.hcl").read_text()
                block = re.search(r'provider "registry\.terraform\.io/' + provider + r'" \{.*?\n\}', lock, re.S)
                if not block:
                    raise SystemExit("Missing locked provider block for child-module test")
                (cwd / ".terraform.lock.hcl").write_text(block.group(0) + "\n")
                init.append("-lockfile=readonly")
            elif "/modules/" not in relative:
                init.append("-lockfile=readonly")
            run(init, cwd, env, relative)
            run(["terraform", "validate", "-no-color"], cwd, env, relative)
            if tests:
                canonical = checkout / "BTP/landing-zone.yaml"
                original = canonical.read_bytes()
                try:
                    if relative == "CloudFoundry/environments":
                        canonical.write_bytes((checkout / "examples/landing-zone.enterprise.yaml").read_bytes())
                    run(["terraform", "test", "-no-color"], cwd, env, relative)
                    if relative == "BTP":
                        canonical.write_bytes((checkout / "examples/landing-zone.enterprise.yaml").read_bytes())
                        run(["terraform", "test", "-no-color", "-test-directory=tests/enterprise"], cwd, env, relative)
                finally:
                    canonical.write_bytes(original)


if __name__ == "__main__":
    main()
