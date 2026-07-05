#!/usr/bin/env python3
from __future__ import annotations

import json
import re
import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
versions = json.loads((ROOT / "config/versions.json").read_text(encoding="utf-8"))["versions"]
project = tomllib.loads((ROOT / "pyproject.toml").read_text(encoding="utf-8"))
dependencies = project["project"]["dependencies"]

def exact_dependency(name: str) -> str:
    prefix = f"{name}=="
    matches = [item[len(prefix):] for item in dependencies if item.startswith(prefix)]
    if len(matches) != 1:
        raise ValueError(f"Expected one exact dependency for {name}, found {matches!r}")
    return matches[0]

checks = {
    "ansible-core": (exact_dependency("ansible-core"), versions["ansible"]["core"]),
    "ansible-lint": (exact_dependency("ansible-lint"), versions["ansible"]["lint"]),
}

requirements = (ROOT / "ansible/requirements.yml").read_text(encoding="utf-8")
match = re.search(
    r"name:\s*community\.docker\s*\n\s*version:\s*[\"']([^\"']+)[\"']",
    requirements,
)
if not match:
    raise ValueError("Could not read community.docker version from ansible/requirements.yml")
checks["community.docker"] = (match.group(1), versions["ansible"]["community_docker"])


python_version = (ROOT / ".python-version").read_text(encoding="utf-8").strip()
checks["python"] = (python_version, versions["ubuntu"]["python"])

workflow = (ROOT / ".github/workflows/validate.yml").read_text(encoding="utf-8")
uv_match = re.search(r'setup-uv@\S+.*?\n\s*with:\s*\n\s*version:\s*"([^"]+)"', workflow, re.S)
if not uv_match:
    raise ValueError("Could not read uv version from .github/workflows/validate.yml")
checks["uv workflow"] = (uv_match.group(1), versions["uv"])

errors = [f"{name}: definition={actual}, config={expected}" for name, (actual, expected) in checks.items() if actual != expected]
if errors:
    print("Version definitions are inconsistent:", file=sys.stderr)
    print("\n".join(f"  - {item}" for item in errors), file=sys.stderr)
    raise SystemExit(1)

print("Version definitions are consistent.")
