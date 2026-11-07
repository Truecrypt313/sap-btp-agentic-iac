#!/usr/bin/env python3
"""Install the pinned, checksum-verified public scanner into a caller-owned directory."""
from pathlib import Path
import argparse
import hashlib
import io
import platform
import tarfile
import urllib.request

VERSION = "8.24.3"
SHA256 = "9991e0b2903da4c8f6122b5c3186448b927a5da4deef1fe45271c3793f4ee29c"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    args = parser.parse_args()
    if platform.system() != "Linux" or platform.machine() not in ["x86_64", "AMD64"]:
        raise SystemExit("Pinned scanner installer supports Linux x86_64 only.")
    url = f"https://github.com/gitleaks/gitleaks/releases/download/v{VERSION}/gitleaks_{VERSION}_linux_x64.tar.gz"
    data = urllib.request.urlopen(url, timeout=60).read()
    if hashlib.sha256(data).hexdigest() != SHA256:
        raise SystemExit("Gitleaks checksum mismatch")
    # Extract exactly one regular file, never archive paths/symlinks.
    with tarfile.open(fileobj=io.BytesIO(data), mode="r:gz") as archive:
        member = archive.getmember("gitleaks")
        if not member.isfile():
            raise SystemExit("Invalid scanner archive")
        binary = archive.extractfile(member).read()
    args.directory.mkdir(parents=True, exist_ok=True)
    target = args.directory / "gitleaks"
    target.write_bytes(binary)
    target.chmod(0o755)
    print(f"Installed checksum-verified Gitleaks {VERSION}")


if __name__ == "__main__":
    main()
