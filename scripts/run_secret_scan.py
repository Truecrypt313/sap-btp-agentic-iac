#!/usr/bin/env python3
"""Redacted Gitleaks scan of the repository file set and optional PR commit range."""
from pathlib import Path
import argparse
import os
import shutil
import subprocess
import tempfile
from check_repository import ROOT, git, repository_files, unsafe_file


def scan_repository(root=ROOT, scanner_name=None, base=None):
    scanner = shutil.which(scanner_name or os.environ.get("GITLEAKS_BINARY", "gitleaks"))
    if not scanner:
        raise SystemExit("Gitleaks required; use scripts/install_gitleaks.py with a temporary directory.")
    version = subprocess.check_output([scanner, "version"], text=True).strip()
    if version != "8.24.3":
        raise SystemExit("Expected pinned Gitleaks 8.24.3")

    with tempfile.TemporaryDirectory(prefix="landing-zone-secret-scan-") as temporary:
        destination = Path(temporary) / "source"
        destination.mkdir()
        config = Path(temporary) / "builtin.toml"
        config.write_text('[extend]\nuseDefault = true\n')
        ignore = Path(temporary) / "empty.ignore"
        ignore.write_text("")
        flags = ["--no-banner", "--redact=100", "--ignore-gitleaks-allow", "--exit-code=1", "--config=" + str(config), "--gitleaks-ignore-path=" + str(ignore)]
        for name in repository_files(root):
            path = root / name
            if unsafe_file(name, b"", path.is_symlink()):
                raise SystemExit("Unsafe scanner input path: " + name)
            target = destination / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(path.read_bytes())
        subprocess.run([scanner, "dir", *flags, str(destination)], check=True)
        if base:
            base = git("rev-parse", "--verify", "--end-of-options", base + "^{commit}", root=root).decode().strip()
            subprocess.run([scanner, "git", *flags, "--log-opts=" + base + "..HEAD", str(root)], check=True)
    print("Redacted secret scanning passed.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--gitleaks", default=os.environ.get("GITLEAKS_BINARY", "gitleaks"))
    parser.add_argument("--base")
    args = parser.parse_args()
    scan_repository(scanner_name=args.gitleaks, base=args.base)


if __name__ == "__main__":
    main()
