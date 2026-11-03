# Goose — Official Context

> [!CAUTION]
> **GENERATED FILE — DO NOT EDIT.**
> This is the compact official entry for this Context Node.
>
> Edit [CONTEXT.src.md](CONTEXT.src.md) instead.

**Node:** Goose  
**Context version:** `0.2.3-draft`

## Local Overview

<!-- contextcanon:format Local Overview
Format: Ordinary Markdown orientation, local to this Node. Any existing placement identity follows its paragraph/item; do not change it.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-overview:start -->
- Each Goose session starts a short-lived container that is removed when the session ends.
  <!-- cc:placement-overview id="ONB-AEFFCCD9AA3E" -->
<!-- contextcanon-placement-overview:end -->

## Local State

<!-- contextcanon:format Local State
Format: Ordinary Markdown describing the current local situation. Any existing placement identity follows its paragraph/item; preserve it.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-state:start -->
- Goose state and session history persist in the `goose-home` Docker volume after a session container is removed.
  <!-- cc:placement-state id="ONB-427D3A5E729C" -->
<!-- contextcanon-placement-state:end -->

## How to use this context

Apply all Rules below to every task in this Node.

## Local Rules

### Onboarding placement

#### `ONB-0A89CA3DEB05` — Goose gets exactly one registered workspace

Each Goose session mounts exactly one explicitly registered host workspace read-write.

#### `ONB-3B9C2D19E779` — Goose root filesystem is read-only

Goose containers use a read-only root filesystem.

#### `ONB-31BF69407B79` — Goose drops Linux privileges

Goose containers drop Linux capabilities and use `no-new-privileges`.

#### `ONB-073CCD7C33CE` — Goose cannot see unrelated host directories

Goose receives no access to unrelated WSL or Windows directories unless they are deliberately registered as the selected workspace.

#### `ONB-8103C2181D78` — Goose rejects broad workspace roots

Broad workspace paths such as `/`, `/home`, `$HOME`, `/mnt` and `/mnt/c` are rejected by the wrapper.

#### `ONB-252B9B6CA5E5` — Goose workspace container path

The selected Goose workspace is mounted at a stable container path under `/workspaces/NAME`.

#### `ONB-EBCD0451BABA` — Selected Goose workspace is delegated authority

The selected workspace is delegated authority: Goose can edit or delete files inside it and can modify its Git repository.

#### `ONB-A0D929FAD90A` — Review Goose changes before publishing

Review Goose changes before committing or pushing them.

### Provider configuration

#### `RULE-3DBB4AA55D53` — Operator-selected Goose connections

The launcher exposes native Goose provider, model and extension configuration without an application-specific provider whitelist, forced public credentials or implicit public-provider fallback. Configuration and connection checks run without a host project mount; Goose settings remain in its persistent home volume.
