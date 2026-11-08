"""Exercise the real pinned scanner with synthetic secrets, never live credentials."""
from pathlib import Path
import os
import shutil
import subprocess
import tempfile
import unittest


class SecretScannerTests(unittest.TestCase):
    def scan(self, content):
        scanner = shutil.which(os.environ.get("GITLEAKS_BINARY", "gitleaks"))
        if not scanner:
            self.fail("Install pinned Gitleaks and set GITLEAKS_BINARY; scanner tests cannot be skipped.")
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            (root / "fixture.txt").write_text(content)
            config = root / "builtin.toml"
            config.write_text('[extend]\nuseDefault = true\n')
            return subprocess.run([scanner, "dir", "--no-banner", "--redact=100", "--ignore-gitleaks-allow", "--config=" + str(config), str(root)], text=True, capture_output=True)

    def test_clean_file(self):
        self.assertEqual(self.scan("Non-secret configuration only").returncode, 0)

    def test_detect_and_redact_synthetic_token(self):
        token = "gh" + "p_" + "0123456789abcdefghijklmnopqrstuvwxYZAB"
        result = self.scan("GITHUB_TOKEN=" + token)
        if token in result.stdout + result.stderr:
            self.fail("Scanner output must redact matched credential values")
        self.assertEqual(result.returncode, 1, "Synthetic token must fail the scan")

    def test_inline_suppression_cannot_hide_token(self):
        token = "gh" + "p_" + "0123456789abcdefghijklmnopqrstuvwxYZAB"
        result = self.scan("GITHUB_TOKEN=" + token + " # gitleaks:allow")
        self.assertEqual(result.returncode, 1)


if __name__ == "__main__":
    unittest.main()
