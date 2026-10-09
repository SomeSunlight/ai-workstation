# Goose — Local Context Source
<!-- ctx:node id="3fd2ae4e-d712-4232-917a-7059b03a3cd4" name="Goose" version="0.2.0-draft" -->

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
- [Containerized application runtimes](..) — `0.2.0-draft` — `relationship=parent`
  <!-- ctx:source id="90dd976e-8753-495b-a631-d708b13878d1" version="0.2.0-draft" normalized-digest="8737d0cf572e2df88cc0e0bac5ecd0133bfbcb998cc5d2bae6ffbcb70985b3d9" package-digest="a3ae6d43bbd4394ee9d15497617a404b1eaa8a01ff6f0b89cc813534887cafc7" -->
<!-- contextcanon-placement-parent:end -->

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

## Local Rules

<!-- contextcanon:format Local Rules
Format: ### Group, then - **Title:** Statement, then indented Why: Rationale. build adds a missing ctx:rule ID after the entry; preserve existing IDs.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-rules:start -->
### Onboarding placement

- **Goose gets exactly one registered workspace:** Each Goose session mounts exactly one explicitly registered host workspace read-write.
  Why: Bounds Goose file authority to the workspace deliberately selected for that session.
  <!-- ctx:rule id="ONB-0A89CA3DEB05" -->

- **Goose root filesystem is read-only:** Goose containers use a read-only root filesystem.
  Why: Limits container-side mutation outside the delegated persistent surfaces.
  <!-- ctx:rule id="ONB-3B9C2D19E779" -->

- **Goose drops Linux privileges:** Goose containers drop Linux capabilities and use `no-new-privileges`.
  Why: Reduces privileges available inside the session container.
  <!-- ctx:rule id="ONB-31BF69407B79" -->

- **Goose cannot see unrelated host directories:** Goose receives no access to unrelated WSL or Windows directories unless they are deliberately registered as the selected workspace.
  Why: Prevents accidental expansion of the agent file-access boundary.
  <!-- ctx:rule id="ONB-073CCD7C33CE" -->

- **Goose rejects broad workspace roots:** Broad workspace paths such as `/`, `/home`, `$HOME`, `/mnt` and `/mnt/c` are rejected by the wrapper.
  Why: Prevents registering host-wide paths that would defeat workspace isolation.
  <!-- ctx:rule id="ONB-8103C2181D78" -->

- **Goose workspace container path:** The selected Goose workspace is mounted at a stable container path under `/workspaces/NAME`.
  Why: Gives sessions a predictable container-side workspace location independent of the host path.
  <!-- ctx:rule id="ONB-252B9B6CA5E5" -->

- **Selected Goose workspace is delegated authority:** The selected workspace is delegated authority: Goose can edit or delete files inside it and can modify its Git repository.
  Why: Makes the consequence of granting a workspace explicit to operators and reviewers.
  <!-- ctx:rule id="ONB-EBCD0451BABA" -->

- **Review Goose changes before publishing:** Review Goose changes before committing or pushing them.
  Why: Keeps publication of agent-made repository changes under human control.
  <!-- ctx:rule id="ONB-A0D929FAD90A" -->
<!-- contextcanon-placement-rules:end -->

### Provider configuration

- **Operator-selected Goose connections:** The launcher exposes native Goose provider, model and extension configuration without an application-specific provider whitelist, forced public credentials or implicit public-provider fallback. Configuration and connection checks run without a host project mount; Goose settings remain in its persistent home volume.
  Why: Supports both local confidential workflows and explicitly selected remote providers while preserving one-workspace isolation.
  <!-- ctx:rule id="RULE-3DBB4AA55D53" -->
