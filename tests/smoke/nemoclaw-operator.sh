#!/usr/bin/env bash
# Offline operator-CLI dispatch regression: no WSL/Podman/NemoClaw installation.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
tmp="$(mktemp -d)"
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/.local/bin"

cat > "$tmp/.local/bin/nemohermes" <<'MOCK'
#!/usr/bin/env bash
set -Eeuo pipefail
[[ "${NEMOCLAW_GATEWAY_RUNTIME:-}" == podman ]] || exit 96
if [[ "${1:-}" == list ]]; then
  printf 'testhermes01 (Hermes)\n'
  exit 0
fi
printf '%s\n' "$*" >> "$FAKE_NEMO_TRACE"
MOCK
chmod +x "$tmp/.local/bin/nemohermes"
trace="$tmp/trace"
touch "$trace"

invoke() {
    HOME="$tmp" FAKE_NEMO_TRACE="$trace" bash "$ROOT/bin/aiw-nemo" "$@"
}

invoke hermes launch testhermes01
invoke hermes start testhermes01
invoke hermes status testhermes01
invoke hermes recover testhermes01
invoke hermes stop testhermes01

cat > "$tmp/expected" <<'EXPECT'
launch testhermes01
testhermes01 start
testhermes01 status
testhermes01 recover
testhermes01 stop
EXPECT
diff -u "$tmp/expected" "$trace"

if invoke hermes launch '../unsafe' >"$tmp/fail.log" 2>&1; then
    echo 'Invalid sandbox name unexpectedly accepted.' >&2; exit 1
fi
if invoke hermes destroy testhermes01 >"$tmp/fail.log" 2>&1; then
    echo 'Destructive unsupported operation unexpectedly accepted.' >&2; exit 1
fi
if invoke hermes launch >"$tmp/fail.log" 2>&1; then
    echo 'Missing sandbox name unexpectedly accepted.' >&2; exit 1
fi
diff -u "$tmp/expected" "$trace"

# Menu is one extra entry; existing selections 1–6 retain their meaning.
printf '7\ntesthermes01\n1\nq\n' | invoke menu >"$tmp/menu.log"
grep -q 'Hermes: launch / stop / start / recover' "$tmp/menu.log"
printf 'launch testhermes01\n' >> "$tmp/expected"
diff -u "$tmp/expected" "$trace"
printf '7\ntesthermes01\n3\nq\n' | invoke menu >"$tmp/menu.log"
printf 'testhermes01 stop\n' >> "$tmp/expected"
diff -u "$tmp/expected" "$trace"

echo '[OK] NemoClaw Hermes lifecycle: exact upstream dispatch; no destructive fallback.'
