#!/usr/bin/env bash
# Render real Compose configuration without a daemon or an LLM request.
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
compose_command=(docker compose)
if [[ -n "${AIW_TEST_COMPOSE_BIN:-}" ]]; then
    compose_command=("$AIW_TEST_COMPOSE_BIN")
elif ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
    printf 'Goose Compose rendering skipped: Compose CLI unavailable.\n'
    exit 0
fi
temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT
cat > "$temp_dir/legacy.env" <<'LEGACY'
GOOSE_PROVIDER=openrouter
GOOSE_MODEL=old-public-model
OPENROUTER_API_KEY=old-public-key
LEGACY
cat > "$temp_dir/local.env" <<'LOCAL'
GOOSE_PROVIDER=selfhosted
GOOSE_MODEL=sparringpartner
GOOSE_SUBAGENT_PROVIDER=selfhosted
GOOSE_SUBAGENT_MODEL=agent
OPENAI_BASE_URL=https://llm.example.net/v1
OPENAI_API_KEY=literal-$key-with-"quotes"
LOCAL
for variant in local missing; do
    AIW_GOOSE_ENV_FILE="$temp_dir/$variant.env" "${compose_command[@]}" \
        --project-name ai-workstation-goose --env-file "$temp_dir/legacy.env" \
        --file "$ROOT/compose/goose.yml" config --format json > "$temp_dir/rendered.json"
    python3 - "$temp_dir/rendered.json" "$variant" <<'PYTHON'
import json
import sys

with open(sys.argv[1]) as stream:
    config = json.load(stream)
service = config["services"]["goose"]
environment = service["environment"]
assert "OPENROUTER_API_KEY" not in environment, "Shared public credentials leaked into Goose"
assert environment["HOME"] == "/home/goose"
assert environment["GOOSE_DISABLE_TELEMETRY"] == "1"
if sys.argv[2] == "local":
    assert environment["GOOSE_PROVIDER"] == "selfhosted"
    assert environment["GOOSE_MODEL"] == "sparringpartner"
    assert environment["GOOSE_SUBAGENT_MODEL"] == "agent"
    # Canonical Compose output escapes dollars for reloading; no lookup occurred.
    assert environment["OPENAI_API_KEY"] == 'literal-$$key-with-"quotes"', "Credential interpolation changed the literal value"
else:
    assert "GOOSE_PROVIDER" not in environment
    assert "GOOSE_MODEL" not in environment
assert service["read_only"] is True
assert service["cap_drop"] == ["ALL"]
assert service["security_opt"] == ["no-new-privileges:true"]
assert len(service["volumes"]) == 1
assert service["volumes"][0]["target"] == "/home/goose"
assert config["volumes"]["goose-home"]["name"] == "ai-workstation_goose-home"
assert config["name"] == "ai-workstation-goose"
assert not config["volumes"]["goose-home"].get("external", False), "Goose home must remain Compose-managed"
PYTHON
done
printf 'Real Goose Compose rendering preserves local routing, literal credentials and isolation.\n'
