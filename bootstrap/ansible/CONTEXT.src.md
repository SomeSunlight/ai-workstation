# Ansible host configuration — Local Context Source
<!-- ctx:node id="ad9cbb59-ae04-4290-9c53-5d70cfefe434" name="Ansible host configuration" version="0.2.0-draft" -->

<!-- contextcanon:format Node
Format: Node metadata follows the # title: ctx:node id="..." name="..." version="...". Preserve existing identity.
Details: CONTEXT-format.md
-->

<!-- contextcanon:source-help:intro:start -->
Edit this local Context source; ContextCanon generates CONTEXT.md from it.
Some sections use a strict syntax. The comments below show the expected format.
New Rules, Topics and Resources receive IDs automatically during build; preserve existing IDs.
See [the source format guide](CONTEXT-format.md) for examples and editing instructions.
<!-- contextcanon:source-help:intro:end -->

## Context Imports

<!-- contextcanon:format Context Imports
Format: - [Name](location) — `version` — `relationship=parent|reference`; optional indented Why:, then ctx:source metadata. Preserve exact pins; use source list/adopt/update for package identity.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-parent:start -->
- [Bootstrap](..) — `0.2.0-draft` — `relationship=parent`
  <!-- ctx:source id="f78265e4-e023-4d7a-9b26-9a917ef68a4a" version="0.2.0-draft" normalized-digest="59cc67c06924af00df20ae1aff6fc6f206b3e2d2dd4ca626834a68a1ee16c8f2" package-digest="1c63971d5569ceacda28e0b95f350c499badbb4a08356b26893bf4d3ad39d327" -->
<!-- contextcanon-placement-parent:end -->

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

## Local Rules

<!-- contextcanon:format Local Rules
Format: ### Group, then - **Title:** Statement, then indented Why: Rationale. build adds a missing ctx:rule ID after the entry; preserve existing IDs.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-rules:start -->
### Onboarding placement

- **Conflicting container packages are not removed automatically:** Existing conflicting container packages are reported, not removed automatically.
  Why: Avoids destructive host changes during Docker setup.
  <!-- ctx:rule id="ONB-B139299ADE50" -->

- **Docker daemon stays on the local Unix socket:** The Docker daemon is exposed only through its local Unix socket.
  Why: Avoids exposing the Docker control plane over a network interface.
  <!-- ctx:rule id="ONB-4D9D0588DD63" -->

- **Only the interactive user joins the docker group:** Only the interactive Linux user joins the powerful `docker` group.
  Why: Keeps Docker-equivalent host authority limited to the intended interactive account.
  <!-- ctx:rule id="ONB-FE26E55B301A" -->
<!-- contextcanon-placement-rules:end -->
