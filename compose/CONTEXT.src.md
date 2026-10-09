# Containerized application runtimes — Local Context Source
<!-- ctx:node id="90dd976e-8753-495b-a631-d708b13878d1" name="Containerized application runtimes" version="0.2.0-draft" -->

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
- [ai-workstation](..) — `0.2.0` — `relationship=parent`
  <!-- ctx:source id="aea56adf-2a26-43f0-b712-3bbeab7a3097" version="0.2.0" normalized-digest="d44fb759965592aa294658f6c1f9de875e410a025972937e4b9d126238cd6739" package-digest="0120798b912bb39f68c061496ff551fd07d7233aa0f03c94558dd1b0024d1a5e" -->
<!-- contextcanon-placement-parent:end -->

## Local Overview

<!-- contextcanon:format Local Overview
Format: Ordinary Markdown orientation, local to this Node. Any existing placement identity follows its paragraph/item; do not change it.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-overview:start -->
- Dockerfiles define the contents of service images.
  <!-- cc:placement-overview id="ONB-C188029871F5" -->

- Compose defines services, mounts, networks and resource limits.
  <!-- cc:placement-overview id="ONB-DBF6C3D9FAA2" -->
<!-- contextcanon-placement-overview:end -->

## Local State

<!-- contextcanon:format Local State
Format: Ordinary Markdown describing the current local situation. Any existing placement identity follows its paragraph/item; preserve it.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-state:start -->
- The currently integrated application runtimes are Goose and Open WebUI.
  <!-- cc:placement-state id="ONB-5475B681ADB6" -->
<!-- contextcanon-placement-state:end -->

## Local Plan

<!-- contextcanon:format Local Plan
Format: Ordinary Markdown describing intended local work. Any existing placement identity follows its paragraph/item; preserve it.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-plan:start -->
- Goose supports operator-selected local/self-hosted and public model connections through its native configuration; hardware inference provisioning remains a separate host runtime concern.
  <!-- cc:placement-plan id="ONB-F2E85C95052E" -->
<!-- contextcanon-placement-plan:end -->

## Local Rules

<!-- contextcanon:format Local Rules
Format: ### Group, then - **Title:** Statement, then indented Why: Rationale. build adds a missing ctx:rule ID after the entry; preserve existing IDs.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-rules:start -->
### Onboarding placement

- **Application containers do not receive the Docker socket:** Agent and application containers do not receive the Docker socket.
  Why: Prevents application runtimes from gaining Docker control-plane authority.
  <!-- ctx:rule id="ONB-C582F0CA4FCE" -->

- **Runtime credentials use protected local storage:** Runtime credentials stay outside Git, images and authored Compose definitions. Applications may use their native persistent secret store; environment-based credentials use a protected untracked file with mode `600`, scoped to the intended application.
  Why: Preserves native provider configuration while avoiding implicit sharing of credentials between unrelated applications.
  <!-- ctx:rule id="ONB-E7F7BAC0BF5F" -->
<!-- contextcanon-placement-rules:end -->
