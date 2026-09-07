from __future__ import annotations

import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CONTEXTCANON_SHA = "fbca8b2f5a6bfcf2aa040917e201674562d5c983"

NODE_NAMES = {
    "CONTEXT.src.md": "ai-workstation",
    "bin/CONTEXT.src.md": "aiw operator interface",
    "bootstrap/CONTEXT.src.md": "Bootstrap",
    "bootstrap/ansible/CONTEXT.src.md": "Ansible host configuration",
    "bootstrap/linux/CONTEXT.src.md": "Linux bootstrap",
    "bootstrap/windows/CONTEXT.src.md": "Windows and WSL bootstrap",
    "compose/CONTEXT.src.md": "Containerized application runtimes",
    "compose/goose/CONTEXT.src.md": "Goose",
    "compose/open-webui/CONTEXT.src.md": "Open WebUI",
}


def run(*args: str) -> None:
    print("+", *args, flush=True)
    subprocess.run(args, cwd=ROOT, check=True)


def migrate_node(path: str, name: str) -> None:
    source = ROOT / path
    text = source.read_text(encoding="utf-8")
    lines = text.splitlines(keepends=True)
    metadata_indexes = [i for i, line in enumerate(lines) if "<!-- ctx:node " in line]
    if len(metadata_indexes) != 1:
        raise RuntimeError(f"{path}: expected exactly one ctx:node metadata line")
    index = metadata_indexes[0]
    line = lines[index]
    if ' name="' in line:
        expected = f'name="{name}"'
        if expected not in line:
            raise RuntimeError(f"{path}: existing explicit name does not match expected {name!r}")
        return
    match = re.search(r'id="[^"]+"', line)
    if match is None:
        raise RuntimeError(f"{path}: ctx:node metadata has no id attribute")
    lines[index] = line[: match.end()] + f' name="{name}"' + line[match.end() :]
    source.write_text("".join(lines), encoding="utf-8")


def finalize_plan() -> None:
    path = ROOT / "PLAN.md"
    text = path.read_text(encoding="utf-8")
    replacements = (
        (
            '- [ ] Migrate all nine authored `CONTEXT.src.md` Nodes to explicit `ctx:node name="..."` metadata, preserving each existing H1-derived canonical name exactly.',
            '- [x] Migrate all nine authored `CONTEXT.src.md` Nodes to explicit `ctx:node name="..."` metadata, preserving each existing H1-derived canonical name exactly.',
        ),
        (
            '- [ ] Leave human Markdown H1 wording unchanged and do not hand-edit compiler-managed `.context/sources/` or generated `CONTEXT/references/` copies.',
            '- [x] Leave human Markdown H1 wording unchanged and do not hand-edit compiler-managed `.context/sources/` or generated `CONTEXT/references/` copies.',
        ),
        (
            f'- [ ] Rebuild generated ContextCanon output using exact tested ContextCanon head `{CONTEXTCANON_SHA}`.',
            f'- [x] Rebuild generated ContextCanon output using exact tested ContextCanon head `{CONTEXTCANON_SHA}`.',
        ),
        (
            '- [ ] Require `contextcanon check --all .` and diff hygiene on the coherent candidate.',
            '- [x] Require `contextcanon check --all .` and diff hygiene on the coherent candidate.',
        ),
    )
    for old, new in replacements:
        if old not in text:
            raise RuntimeError(f"PLAN checkpoint line not found: {old}")
        text = text.replace(old, new, 1)
    text += (
        "\nIssue #1 implementation checkpoint: all nine authored Nodes now carry explicit canonical "
        "`ctx:node name` metadata, generated ContextCanon output was rebuilt with the exact PR #18 "
        f"head `{CONTEXTCANON_SHA}`, and `contextcanon check --all .` plus diff hygiene passed. "
        "The review-PR item remains open until the PR is created.\n"
    )
    path.write_text(text, encoding="utf-8")


def main() -> None:
    plan = (ROOT / "PLAN.md").read_text(encoding="utf-8")
    if "## ContextCanon explicit Node-name migration — Issue #1" not in plan:
        raise RuntimeError("Issue #1 PLAN checkpoint must exist before migration")

    run("git", "config", "user.name", "github-actions[bot]")
    run("git", "config", "user.email", "41898282+github-actions[bot]@users.noreply.github.com")

    for path, name in NODE_NAMES.items():
        migrate_node(path, name)

    run(sys.executable, "-m", "pip", "install", f"git+https://github.com/SomeSunlight/context-canon.git@{CONTEXTCANON_SHA}")
    run("contextcanon", "build", "--all", ".")
    run("contextcanon", "check", "--all", ".")
    run("git", "diff", "--check")

    finalize_plan()
    run("git", "diff", "--check")

    run("git", "rm", ".github/scripts/contextcanon_issue1_finalize.py", ".github/workflows/contextcanon-issue1-finalizer.yml")
    run("git", "add", "-A")
    run("git", "commit", "-m", "Migrate Context Node names to explicit metadata (#1)")
    run("git", "push", "origin", "HEAD:agent/explicit-context-node-names")


if __name__ == "__main__":
    main()
