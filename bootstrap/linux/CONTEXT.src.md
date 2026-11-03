# Linux bootstrap — Local Context Source
<!-- ctx:node id="1e85ca79-6021-4b66-ae0c-4da90f78d6e9" name="Linux bootstrap" version="0.2.3-draft" -->

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
- [Bootstrap](..) — `0.2.2-draft` — `relationship=parent`
  <!-- ctx:source id="f78265e4-e023-4d7a-9b26-9a917ef68a4a" version="0.2.2-draft" normalized-digest="1e795319abed6f4d66c0c48f227a5bc89b72dc3f50b394b549489a660c8623b8" package-digest="1cea3ebe40730eb2d962e15cb9c5e967ab6d13443a030fead969db897d1b68c7" -->
<!-- contextcanon-placement-parent:end -->

## Local Overview

<!-- contextcanon:format Local Overview
Format: Ordinary Markdown orientation, local to this Node. Any existing placement identity follows its paragraph/item; do not change it.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-overview:start -->
- Linux bootstrap owns minimal packages, uv and the locked Ansible runtime.
  <!-- cc:placement-overview id="ONB-F6A1EFFA33BF" -->
<!-- contextcanon-placement-overview:end -->
