# Ansible host configuration — Official Context

> [!CAUTION]
> **GENERATED FILE — DO NOT EDIT.**
> This is the compact official entry for this Context Node.
>
> Edit [CONTEXT.src.md](CONTEXT.src.md) instead.

**Node:** Ansible host configuration  
**Context version:** `0.2.3-draft`

## Local Overview

<!-- contextcanon:format Local Overview
Format: Ordinary Markdown orientation, local to this Node. Any existing placement identity follows its paragraph/item; do not change it.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-overview:start -->
- Ansible owns Ubuntu host state and Docker Engine.
  <!-- cc:placement-overview id="ONB-444A1E93B553" -->
<!-- contextcanon-placement-overview:end -->

## Local State

<!-- contextcanon:format Local State
Format: Ordinary Markdown describing the current local situation. Any existing placement identity follows its paragraph/item; preserve it.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-state:start -->
- The automation environment requires Python 3.12.*.
  <!-- cc:placement-state id="ONB-F7A368F3CAE1" -->

- `ansible-core` is pinned to 2.21.1.
  <!-- cc:placement-state id="ONB-73F6A9557DB5" -->

- `ansible-lint` is pinned to 26.6.0.
  <!-- cc:placement-state id="ONB-D32F29A7A6AB" -->
<!-- contextcanon-placement-state:end -->

## How to use this context

Apply all Rules below to every task in this Node.

## Local Rules

### Onboarding placement

#### `ONB-B139299ADE50` — Conflicting container packages are not removed automatically

Existing conflicting container packages are reported, not removed automatically.

#### `ONB-4D9D0588DD63` — Docker daemon stays on the local Unix socket

The Docker daemon is exposed only through its local Unix socket.

#### `ONB-FE26E55B301A` — Only the interactive user joins the docker group

Only the interactive Linux user joins the powerful `docker` group.
