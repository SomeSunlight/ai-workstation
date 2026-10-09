# Open WebUI — Local Context Source
<!-- ctx:node id="dbf13d04-e686-4cda-9434-c439e23bb400" name="Open WebUI" version="0.2.0-draft" -->

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
- Open WebUI runs as a persistent Docker service accessed from the Windows browser through WSL localhost forwarding.
  <!-- cc:placement-overview id="ONB-15284536311B" -->

- Open WebUI reaches configured model providers over the network.
  <!-- cc:placement-overview id="ONB-57A446045BBD" -->
<!-- contextcanon-placement-overview:end -->

## Local State

<!-- contextcanon:format Local State
Format: Ordinary Markdown describing the current local situation. Any existing placement identity follows its paragraph/item; preserve it.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-state:start -->
- The default Open WebUI address is `http://localhost:3000`.
  <!-- cc:placement-state id="ONB-9745CD6E1E1C" -->

- Open WebUI stores its persistent state in a named Docker volume.
  <!-- cc:placement-state id="ONB-35A21B57D6C3" -->

- The first Open WebUI account becomes the local administrator.
  <!-- cc:placement-state id="ONB-725C7FD86EA6" -->
<!-- contextcanon-placement-state:end -->

## Local Rules

<!-- contextcanon:format Local Rules
Format: ### Group, then - **Title:** Statement, then indented Why: Rationale. build adds a missing ctx:rule ID after the entry; preserve existing IDs.
Details: CONTEXT-format.md
-->

<!-- contextcanon-placement-rules:start -->
### Onboarding placement

- **Open WebUI binds to localhost:** Open WebUI binds only to `127.0.0.1` on the WSL host by default.
  Why: Keeps the browser service off LAN-facing interfaces unless an operator deliberately adds stronger controls.
  <!-- ctx:rule id="ONB-055DC22CD3AD" -->

- **Open WebUI receives no host workspace:** Open WebUI receives no host workspace.
  Why: Prevents the service from gaining direct access to host project files.
  <!-- ctx:rule id="ONB-5CC56E3A7A35" -->

- **Open WebUI receives no Docker socket:** Open WebUI receives no Docker socket.
  Why: Prevents the web application from controlling the Docker daemon.
  <!-- ctx:rule id="ONB-84AA72A87719" -->

- **Open WebUI keeps authentication enabled:** Open WebUI keeps authentication enabled.
  Why: Maintains an authenticated boundary even while the service is localhost-only.
  <!-- ctx:rule id="ONB-DEF73E20EAE8" -->

- **Use a strong Open WebUI administrator password:** Use a strong password for the Open WebUI administrator account.
  Why: The first local account has administrator authority over the service.
  <!-- ctx:rule id="ONB-EAAB7BB9AD74" -->

- **Do not expose Open WebUI without added controls:** Do not publish the Open WebUI localhost port through a proxy or LAN interface without appropriate TLS, authentication and network controls.
  Why: Localhost binding is the default safety boundary; broader exposure requires compensating controls.
  <!-- ctx:rule id="ONB-4D2A3FDC8A51" -->
<!-- contextcanon-placement-rules:end -->
