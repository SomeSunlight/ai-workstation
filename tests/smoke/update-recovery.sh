#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

remote="$tmp/remote.git"
work="$tmp/work"
marker="$tmp/install.marker"

git init --bare "$remote" >/dev/null
git init -b main "$work" >/dev/null

git -C "$work" config user.name "AIW Test"
git -C "$work" config user.email "aiw-test@example.invalid"
mkdir -p "$work/bin"
cp "$ROOT/bin/aiw-core" "$work/bin/aiw-core"
chmod +x "$work/bin/aiw-core"
cat > "$work/install.sh" <<'EOF_INSTALL'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s\n' "$*" > "${AIW_TEST_INSTALL_MARKER:?}"
EOF_INSTALL
chmod +x "$work/install.sh"

git -C "$work" add bin/aiw-core install.sh
git -C "$work" commit -m "Test installation" >/dev/null
git -C "$work" remote add origin "$remote"
git -C "$work" push -u origin main >/dev/null

git -C "$work" switch -c agent/test-update >/dev/null
git -C "$work" push -u origin agent/test-update >/dev/null
git -C "$work" push origin --delete agent/test-update >/dev/null

[[ "$(git -C "$work" branch --show-current)" == "agent/test-update" ]]
[[ "$(git -C "$work" config --get branch.agent/test-update.merge)" == "refs/heads/agent/test-update" ]]

AIW_TEST_INSTALL_MARKER="$marker" "$work/bin/aiw-core" update

[[ "$(git -C "$work" branch --show-current)" == "main" ]] || {
    echo "Update recovery did not switch to main." >&2
    exit 1
}
[[ "$(git -C "$work" rev-parse --abbrev-ref --symbolic-full-name '@{u}')" == "origin/main" ]] || {
    echo "Recovered main branch does not track origin/main." >&2
    exit 1
}
git -C "$work" show-ref --verify --quiet refs/heads/agent/test-update || {
    echo "Update recovery deleted the old local review branch." >&2
    exit 1
}
[[ -f "$marker" ]] || {
    echo "Installer was not rerun after update recovery." >&2
    exit 1
}
[[ "$(cat "$marker")" == "install --yes" ]] || {
    echo "Installer arguments changed unexpectedly." >&2
    exit 1
}

printf 'Deleted-upstream update recovery is valid.\n'
