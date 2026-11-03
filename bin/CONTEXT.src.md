# aiw operator interface — Local Context Source
<!-- ctx:node id="6417ee7c-a9d0-40c7-ada3-6762d4a3900b" name="aiw operator interface" version="0.2.3-draft" -->

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
- [ai-workstation](..) — `0.2.2` — `relationship=parent`
  <!-- ctx:source id="aea56adf-2a26-43f0-b712-3bbeab7a3097" version="0.2.2" normalized-digest="72c14b6f6322f4a87356e73c0b28c2ab93c9824b866cfd4d370fdda2725d95a9" package-digest="3ed99859f780cf0cba266d708b10d414a642622ca76d50ee69e861de3f2ad8b0" -->
<!-- contextcanon-placement-parent:end -->

## Local Overview

<!-- contextcanon:format Local Overview
Format: Ordinary Markdown orientation, local to this Node. Any existing placement identity follows its paragraph/item; do not change it.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-overview:start -->
- `aiw` is the stable user interface for installation and operation.
  <!-- cc:placement-overview id="ONB-C952C6C6635C" -->
<!-- contextcanon-placement-overview:end -->
