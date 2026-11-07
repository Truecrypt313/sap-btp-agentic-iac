"""Shared conservative credential-key policy; never report parameter values."""
import re

SECRET_KEY_PATTERN = r"(?i)(password|passwd|secret|token|credentials|apikey|privatekey)$"
SECRET_KEY = re.compile(SECRET_KEY_PATTERN)


def sensitive_key(key):
    return bool(SECRET_KEY.search(re.sub(r"[^A-Za-z0-9]", "", key)))
