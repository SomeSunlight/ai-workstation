"""Read native configuration offline; report routing without exposing credentials."""

import sys

import yaml


def scalar(value):
    return value if isinstance(value, str) and value.strip() else ""


def display(value):
    return "".join(char if char.isprintable() else "?" for char in value)


def main():
    # The first four lines contain explicit container environment overrides.
    overrides = [sys.stdin.readline().rstrip("\n").partition(":") for _ in range(4)]

    def override(index, default):
        present, _, value = overrides[index]
        return scalar(value) if present == "x" else default

    try:
        data = yaml.safe_load(sys.stdin.read()) or {}
        if not isinstance(data, dict):
            raise ValueError
        provider = override(
            0, scalar(data.get("active_provider")) or scalar(data.get("GOOSE_PROVIDER"))
        )
        providers = data.get("providers") or {}
        selected = providers.get(provider, {}) if isinstance(providers, dict) else {}
        model = override(
            1,
            scalar(selected.get("model") if isinstance(selected, dict) else None)
            or scalar(data.get("GOOSE_MODEL")),
        )
        sub_provider = override(2, scalar(data.get("GOOSE_SUBAGENT_PROVIDER")))
        sub_model = override(3, scalar(data.get("GOOSE_SUBAGENT_MODEL")))
    except (yaml.YAMLError, ValueError, TypeError):
        print("Goose configuration  : unreadable (configuration values withheld)")
        return 1
    configured = bool(provider and model)
    print(f"Goose configuration  : {'configured' if configured else 'incomplete'}")
    print(f"Goose provider       : {display(provider) or 'not configured'}")
    print(f"Goose model          : {display(model) or 'not configured'}")
    if sub_provider or sub_model:
        print(
            f"Goose subagent defaults: {display(sub_provider) or 'inherit provider'} / {display(sub_model) or 'inherit model'} (release-dependent)"
        )
    return 0 if configured or sys.argv[1] == "status" else 1


if __name__ == "__main__":
    sys.exit(main())
