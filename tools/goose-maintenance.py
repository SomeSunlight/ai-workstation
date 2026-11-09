"""Read the operator's Goose YAML safely; never print credentials or parser details."""

import re
import sys
from urllib.parse import urlsplit, urlunsplit

import yaml

ROUTE_KEYS = {
    "url", "base_url", "api_base_url", "endpoint", "api_endpoint",
    "host", "base_path", "openai_base_url", "openai_host", "openai_base_path",
}
MODEL_KEYS = {
    "active_provider", "model", "model_name", "model_id",
    "provider", "goose_provider", "goose_model",
    "goose_subagent_provider", "goose_subagent_model",
    "goose_planner_provider", "goose_planner_model",
}
ENV_KEYS = {
    "GOOSE_PROVIDER", "GOOSE_MODEL", "GOOSE_SUBAGENT_PROVIDER",
    "GOOSE_SUBAGENT_MODEL", "GOOSE_PLANNER_PROVIDER", "GOOSE_PLANNER_MODEL",
    "OPENAI_BASE_URL", "OPENAI_HOST", "OPENAI_BASE_PATH",
}


def yaml_mapping(stream):
    try:
        value = yaml.safe_load(stream)
    except yaml.YAMLError:
        raise ValueError("Invalid YAML (details withheld)") from None
    if not isinstance(value, dict):
        raise ValueError("Goose config must be a YAML mapping")
    return value


def clean(value):
    return "".join(c if c.isprintable() and c not in "\x1b" else "?" for c in str(value))


def safe_url(value):
    text = clean(value)
    if "://" not in text:
        return text.split("?", 1)[0].split("#", 1)[0]
    try:
        parts = urlsplit(text)
        host = parts.hostname or ""
        if parts.port is not None:
            host += ":" + str(parts.port)
        path = re.sub(
            r"(?i)(/(?:token|secret|apikey|api-key|auth)/)[^/]+",
            r"\1[redacted]",
            parts.path,
        )
        return urlunsplit((parts.scheme, host, path, "", ""))
    except ValueError:
        return "[URL withheld: invalid]"


def show_config(config):
    print("Saved native YAML (only routing fields shown; secrets withheld):")
    print("  active_provider:", clean(config.get("active_provider", "not set")))
    providers = config.get("providers", {})
    if isinstance(providers, dict):
        print("  providers:", ", ".join(clean(x) for x in providers) or "(none)")
    seen = set()
    counter = 0

    def walk(node, location="", depth=0):
        nonlocal counter
        if depth > 8 or counter > 100 or not isinstance(node, dict):
            return
        if id(node) in seen:
            return
        seen.add(id(node))
        for key, value in node.items():
            counter += 1
            if counter > 100:
                break
            k = clean(key)
            path = f"{location}.{k}" if location else k
            kind = str(key).lower()
            # Never print unknown fields, secrets or object representations.
            if kind in ROUTE_KEYS and isinstance(value, (str, int, float)):
                print(f"  {path}: {safe_url(value)}")
            elif kind in MODEL_KEYS and isinstance(value, (str, int, float)):
                print(f"  {path}: {clean(value)}")
            elif isinstance(value, dict):
                walk(value, path, depth + 1)

    walk(config)
    print("  Other native fields and credentials: withheld")


def show_env(path):
    try:
        with open(path, encoding="utf-8") as stream:
            lines = stream.readlines()
    except FileNotFoundError:
        print("Goose-only environment overrides: none")
        return
    except OSError:
        print("Goose-only environment overrides: unreadable")
        return
    values = {}
    for line in lines:
        if not line.strip() or line.lstrip().startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        if key in ENV_KEYS:
            values[key] = value.rstrip("\r\n")
    print("Goose-only environment overrides (selected safe fields):")
    for key, value in values.items():
        print(f"  {key}: {safe_url(value) if key.lower().endswith(('url', 'host', 'path')) else clean(value)}")
    if not values:
        print("  No routing overrides")


def main():
    mode = sys.argv[1]
    try:
        config = yaml_mapping(sys.stdin)
    except ValueError as error:
        print(str(error), file=sys.stderr)
        return 1
    if mode == "validate":
        print("[OK] Native Goose YAML syntax and root mapping validated.")
        return 0
    if mode == "inspect":
        show_config(config)
        show_env(sys.argv[2])
        return 0
    return 2


if __name__ == "__main__":
    sys.exit(main())
