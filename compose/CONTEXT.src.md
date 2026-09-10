# Containerized application runtimes — Local Context Source
<!-- ctx:node id="90dd976e-8753-495b-a631-d708b13878d1" name="Containerized application runtimes" version="0.1.1-draft" -->

## Parent Context Node

<!-- contextcanon-placement-parent:start -->
- [ai-workstation](..) — `0.1.1`
  <!-- ctx:parent id="aea56adf-2a26-43f0-b712-3bbeab7a3097" version="0.1.1" normalized-digest="d8fce480dca898b6065ff14ff1ec111b1cc4f03db80af71fc205b28d1beb4530" package-digest="f08e5ab3eb59e3c5252282bba9f2879bf891ffc995b97def0b1619647346c613" -->
<!-- contextcanon-placement-parent:end -->

## Local Overview

<!-- contextcanon-placement-overview:start -->
<!-- cc:placement-overview id="ONB-C188029871F5" -->
- Dockerfiles define the contents of service images.

<!-- cc:placement-overview id="ONB-DBF6C3D9FAA2" -->
- Compose defines services, mounts, networks and resource limits.
<!-- contextcanon-placement-overview:end -->

## Local State

<!-- contextcanon-placement-state:start -->
<!-- cc:placement-state id="ONB-5475B681ADB6" -->
- The currently integrated application runtimes are Goose and Open WebUI.
<!-- contextcanon-placement-state:end -->

## Local Plan

<!-- contextcanon-placement-plan:start -->
<!-- cc:placement-plan id="ONB-F2E85C95052E" -->
- Local model integration is intentionally deferred to the next phase.
<!-- contextcanon-placement-plan:end -->

## Local Rules

<!-- contextcanon-placement-rules:start -->
### Onboarding placement

- **Application containers do not receive the Docker socket:** Agent and application containers do not receive the Docker socket.
  Why: Prevents application runtimes from gaining Docker control-plane authority.
  <!-- ctx:rule id="ONB-C582F0CA4FCE" -->

- **Runtime credentials use the protected env file:** Runtime credentials are read from the Git-ignored `.env` file with mode `600`.
  Why: Centralizes runtime secrets in an untracked file with restrictive permissions.
  <!-- ctx:rule id="ONB-E7F7BAC0BF5F" -->
<!-- contextcanon-placement-rules:end -->
