#!/usr/bin/env python3
"""Read-only Git/file/lock safety checks, including untracked non-ignored files."""
from pathlib import Path, PurePosixPath
import argparse
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def git(*args, root=ROOT):
    return subprocess.check_output(["git", *args], cwd=root)


def repository_files(root=ROOT):
    return [p for p in git("ls-files", "--cached", "--others", "--exclude-standard", "-z", root=root).decode().split("\0") if p]


def unsafe_file(name, content, symlink=False):
    path = PurePosixPath(name)
    if path.is_absolute() or ".." in path.parts or symlink:
        return "unsafe path or symlink"
    if any(part in [".terraform", "__pycache__", ".venv"] for part in path.parts):
        return "local generated cache"
    if re.search(r"(?i)(\.tfstate|\.tfplan|\.tfvars|(^|/)\.env($|\.)|(^|/)(credentials|secrets?)(\.|$)|\.(pem|key|p12|pfx)$)", name):
        return "state, plan, runtime inputs or credential file"
    if len(content) > 2_000_000 or b"\0" in content:
        return "oversized or binary artifact"
    try:
        content.decode("utf-8")
    except UnicodeError:
        return "non-UTF-8 artifact"
    return None


def lock_blocks(text):
    return dict(re.findall(r'provider "([^"]+)" (\{.*?\n\})', text, re.S))


def check_locks(root, base):
    expected = {
        "registry.terraform.io/sap/btp": "1.27.0",
        "registry.terraform.io/hashicorp/random": "3.9.1",
        "registry.terraform.io/cloudfoundry/cloudfoundry": "1.18.0",
        "registry.terraform.io/hashicorp/tfe": "0.83.0",
        "registry.terraform.io/hashicorp/external": "2.3.5",
    }
    for relative in ["BTP/.terraform.lock.hcl", "CloudFoundry/.terraform.lock.hcl", "CloudFoundry/environments/.terraform.lock.hcl", "BTP/projects/.terraform.lock.hcl", "CloudFoundry/projects/.terraform.lock.hcl"]:
        if not (root / relative).exists():
            continue  # Unit-test fixtures may intentionally include only legacy roots.
        current = lock_blocks((root / relative).read_text())
        for provider, block in current.items():
            version = re.search(r'version\s*=\s*"([^"]+)"', block).group(1)
            if provider not in expected or version != expected[provider]:
                raise ValueError("Unreviewed provider/version in " + relative)
            if provider == "registry.terraform.io/hashicorp/external" and relative != "BTP/projects/.terraform.lock.hcl":
                raise ValueError("Directory preflight provider is only permitted in the isolated BTP/projects root")
        if not base:
            continue
        previous = subprocess.run(["git", "show", f"{base}:{relative}"], cwd=root, capture_output=True)
        if previous.returncode:
            continue  # New isolated root; exact approved versions still checked.
        for provider, block in lock_blocks(previous.stdout.decode()).items():
            if current.get(provider) != block:
                raise ValueError("Existing locked provider block changed or removed: " + relative)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="main")
    args = parser.parse_args()
    base = git("rev-parse", "--verify", "--end-of-options", args.base + "^{commit}").decode().strip()
    for name in repository_files():
        path = ROOT / name
        if not path.exists() and not path.is_symlink():
            raise SystemExit("Tracked file missing: " + name)
        error = unsafe_file(name, b"" if path.is_symlink() else path.read_bytes(), path.is_symlink())
        if error:
            raise SystemExit(f"Unsafe repository file: {name}: {error}")
    subprocess.run(["git", "diff", "--check", base, "--"], cwd=ROOT, check=True)
    # Git diff ignores untracked additions; check their entire added contents too.
    for name in git("ls-files", "--others", "--exclude-standard", "-z").decode().split("\0"):
        if name and any(line.rstrip(" \t") != line for line in (ROOT / name).read_text().splitlines()):
            raise SystemExit("Whitespace error in untracked addition: " + name)
    try:
        check_locks(ROOT, base)
    except ValueError as error:
        raise SystemExit(str(error))
    print("Repository files, Git diff and existing provider lock blocks passed.")


if __name__ == "__main__":
    main()
