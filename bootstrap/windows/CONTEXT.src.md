# Windows and WSL bootstrap — Local Context Source
<!-- ctx:node id="a46c5141-dcdf-4f28-9839-4053a02e04cf" name="Windows and WSL bootstrap" version="0.2.0-draft" -->

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
- PowerShell owns Windows, WSL, reboot continuation and distribution lifecycle.
  <!-- cc:placement-overview id="ONB-824062AB56E8" -->
<!-- contextcanon-placement-overview:end -->

## Local Rules

<!-- contextcanon:format Local Rules
Format: ### Group, then - **Title:** Statement, then indented Why: Rationale. build adds a missing ctx:rule ID after the entry; preserve existing IDs.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-rules:start -->
### Onboarding placement

- **Existing WSL distributions are never removed:** Existing WSL distributions are never unregistered or deleted automatically.
  Why: Protects existing Linux environments while allowing the installer to be rerun or used for clean-room testing.
  <!-- ctx:rule id="ONB-DE918FE55390" -->
<!-- contextcanon-placement-rules:end -->

## Local Topics

<!-- contextcanon:format Local Topics
Format: ### Title, condition text, Required: and/or Optional:, then - Resource: `path` or - Context Node: `node-path`. Resource may have indented Why:. build adds missing Topic/Resource IDs after their entries; preserve existing IDs.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-topics:start -->
### Clean-room WSL test procedure

When testing installation in a separate WSL distribution or rerunning the clean-room reinstall procedure, read the clean-room test guide.

Required:
- Resource: `../../docs/clean-room-test.md`
  <!-- ctx:resource id="RESOURCE-2EF99A3C0CBF" -->

<!-- ctx:topic id="ONB-CF243F7DFF6C" -->
<!-- contextcanon-placement-topics:end -->
