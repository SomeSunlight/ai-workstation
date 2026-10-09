# Bootstrap — Local Context Source
<!-- ctx:node id="f78265e4-e023-4d7a-9b26-9a917ef68a4a" name="Bootstrap" version="0.2.0-draft" -->

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

## Local Rules

<!-- contextcanon:format Local Rules
Format: ### Group, then - **Title:** Statement, then indented Why: Rationale. build adds a missing ctx:rule ID after the entry; preserve existing IDs.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-rules:start -->
### Onboarding placement

- **Keep installation entry points thin:** Keep installation entry points thin and move implementation into modules.
  Why: Preserves a small entry-point surface while keeping implementation maintainable.
  <!-- ctx:rule id="ONB-14050ED3235E" -->

- **Preserve installer idempotency:** Preserve idempotency: a second run must be safe.
  Why: Installation is explicitly designed to be rerun after interruption or partial completion.
  <!-- ctx:rule id="ONB-F02E76A8ECF4" -->

- **No automatic destructive migration:** Never introduce an automatic destructive migration.
  Why: Destructive changes require explicit human control rather than implicit installer behavior.
  <!-- ctx:rule id="ONB-DDE1BB850066" -->
<!-- contextcanon-placement-rules:end -->
